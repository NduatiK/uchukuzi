module Errors exposing
    ( InputError, Errors(..)
    , toServerSideErrors, toValidationError, toValidationErrors, emptyInputError
    , captionFor, toMsg, unwrapInputError
    , containServerErrorFor
    , customInputErrorsFor, errorToString, loginErrorToString
    )

{-| This module makes it easier to deal with errors intended for the UI.
It maps server and validation error definitions to the correct inputs


# Definition

@docs InputError, Errors


# Constructors

@docs toServerSideErrors, toValidationError, toValidationErrors, emptyInputError


# Using errors

@docs captionFor, toMsg, unwrapInputError


# Query Helpers

@docs containServerErrorFor

-}

import Api
import Dict
import Http
import Json.Decode as Decode exposing (Decoder, decodeString, dict, list, string)


{-| A list of error strings intended to be displayed on an input field
-}
type alias InputError validationError =
    { visibleName : FieldName
    , errors : List (Errors validationError)
    }


emptyInputError =
    InputError "" []


{-| Represent errors generated from failing validation on the client
and from server side errors
-}
type Errors validationError
    = ValidationError validationError ErrorString
    | ServerSideError FieldName (List ErrorString)


type alias FieldName =
    String


type alias ErrorString =
    String


{-| Match validation and server errors intended for a given field;
however when presenting the error, describe the field with another name

    [ ValidationError1 ]
    |> customInputErrorsFor
        { problems = [ServerSideError "manager_email" ["is already taken"]]
        , serverFieldName = "manager_email"
        , visibleName = "email"
        }
    |> unwrapInputError
        -- Just ["The email is already taken"]}

-}
customInputErrorsFor :
    { problems : List (Errors validationError)
    , serverFieldName : String
    , visibleName : String
    }
    -> List validationError
    -> Maybe (InputError validationError)
customInputErrorsFor { problems, serverFieldName, visibleName } validationErrorsToMatch =
    let
        possibleValidationErrors =
            validationErrorsToMatch
                |> List.map (\x -> ValidationError x "")

        matchingValidationErrors =
            problems
                |> List.filter (\x -> possibleValidationErrors |> contains x)

        matchingServerErrors =
            problems
                |> List.filter (\x -> [ ServerSideError serverFieldName [] ] |> contains x)

        allErrors =
            matchingValidationErrors ++ matchingServerErrors
    in
    case allErrors of
        [] ->
            Nothing

        _ ->
            Just
                (InputError visibleName allErrors)


{-| Match validation and server errors intended for a given field
For server errors it attempts to sanitize the field name before displaying it as part of the error

    (captionFor [ServerSideError "manager_email" ["is already taken"]] "manager_email" [LongEmail, "The email is too long"])
    |> unwrapInputError
        -- Just ["The manager_email is already taken", "The email is too long"]}

-}
captionFor :
    List (Errors validationError)
    -> String
    -> List validationError
    -> Maybe (InputError validationError)
captionFor formProblems fieldName errorsToMatch =
    customInputErrorsFor
        { problems = formProblems
        , serverFieldName = fieldName
        , visibleName = fieldName
        }
        errorsToMatch


toValidationError : ( a, String ) -> Errors a
toValidationError problem =
    ValidationError (Tuple.first problem) (Tuple.second problem)


toValidationErrors : List ( a, String ) -> List (Errors a)
toValidationErrors problems =
    List.map toValidationError problems


toServerSideErrors : Http.Error -> List (Errors a)
toServerSideErrors formErrors =
    List.map (\x -> ServerSideError (Tuple.first x) (Tuple.second x)) (decodeFormErrors formErrors)


contains : Errors internalError -> List (Errors internalError) -> Bool
contains anError listOfErrors =
    List.any
        (\x ->
            case ( anError, x ) of
                ( ServerSideError aFieldName _, ServerSideError xFieldName _ ) ->
                    aFieldName == xFieldName

                ( ValidationError aError _, ValidationError xError _ ) ->
                    aError == xError

                _ ->
                    False
        )
        listOfErrors


containServerErrorFor : List FieldName -> List (Errors internalError) -> Bool
containServerErrorFor fields problems =
    List.any
        (\field ->
            problems |> contains (ServerSideError field [])
        )
        fields



--- API ERRORS


type NetworkError
    = Unauthorized
    | BadRequest String


decodeErrors : Http.Error -> ( NetworkError, Cmd msg )
decodeErrors error =
    let
        defaultError =
            "Something went wrong, please reload the page"

        networkError =
            case error of
                Http.BadStatus response ->
                    if response.status.code == 401 then
                        Unauthorized

                    else
                        BadRequest
                            (response.body
                                |> decodeString (Decode.at [ "errors", "detail" ] string)
                                |> Result.withDefault defaultError
                            )

                _ ->
                    BadRequest defaultError
    in
    ( networkError, handleError networkError )


handleError : NetworkError -> Cmd msg
handleError error =
    case error of
        Unauthorized ->
            Cmd.batch
                [ Api.setCredentials Nothing
                ]

        _ ->
            Cmd.none


decodeFormErrors : Http.Error -> List ( String, List String )
decodeFormErrors error =
    let
        fieldDecoder : Decoder (Dict.Dict String (List String))
        fieldDecoder =
            Decode.at [ "errors", "detail" ] (dict (list string))

        decodeField response =
            response.body
                |> decodeString fieldDecoder
    in
    case error of
        Http.BadStatus response ->
            case decodeField response of
                Result.Err _ ->
                    []

                Result.Ok dictionary ->
                    Dict.toList dictionary

        _ ->
            []


toNetworkError : Http.Error -> NetworkError
toNetworkError =
    decodeErrors >> Tuple.first


{-| Produce command for received Http.Error

    toMsg [ Unauthorized ] -- Api.logout

-}
toMsg : Http.Error -> Cmd msg
toMsg =
    decodeErrors >> Tuple.second


{-| Produce error string when user is logged in
-}
errorToString : Http.Error -> String
errorToString error =
    case toNetworkError error of
        Unauthorized ->
            "Your session has expired, please log in again"

        BadRequest errorText ->
            errorText


{-| Produce error string when user is not logged in
-}
loginErrorToString : Http.Error -> String
loginErrorToString error =
    case toNetworkError error of
        Unauthorized ->
            "Invalid email or password"

        BadRequest errorText ->
            errorText


{-| Unwrap strings inside an InputError for error rendering
-}
unwrapInputError : InputError e -> Maybe (List String)
unwrapInputError error =
    let
        beautifyError =
            \x ->
                case x of
                    ValidationError _ string ->
                        [ string ]

                    ServerSideError _ strings ->
                        List.map (\str -> "The " ++ String.replace "_" " " error.visibleName ++ " " ++ str) strings
    in
    case List.concatMap beautifyError error.errors of
        [] ->
            Nothing

        errorStrings ->
            Just errorStrings
