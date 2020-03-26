port module Api exposing (..)

import Api.Endpoint as Endpoint exposing (Endpoint)
import Http exposing (Body)
import Json.Decode as Decode exposing (Decoder, Value, bool, decodeString, field, float, int, list, nullable, string)
import Json.Decode.Pipeline exposing (required, requiredAt, resolve)
import Json.Encode as Encode
import RemoteData exposing (RemoteData(..), WebData)
import Route exposing (LoginRedirect, Route)
import Session exposing (Cred, Session)


get : Session -> Endpoint -> Decoder a -> Cmd (WebData a)
get session url decoder =
    Endpoint.get url session decoder


post : Session -> Endpoint -> Body -> Decoder a -> Cmd (WebData a)
post session url body decoder =
    Endpoint.post url session body decoder


patch : Session -> Endpoint -> Body -> Decoder a -> Cmd (WebData a)
patch session url body decoder =
    Endpoint.patch url session body decoder


decodeErrors : Http.Error -> Error
decodeErrors error =
    case error of
        Http.BadStatus response ->
            if response.status.code == 401 then
                Unauthorized

            else
                BadRequest
                    -- Debug.log "response.body"
                    (response.body
                        |> decodeString (Decode.at [ "errors", "detail" ] string)
                        |> Result.withDefault "Server error"
                    )

        -- response.body
        --     |> decodeString (Decode.at [ "errors", "detail" ] string)
        --     |> Result.withDefault "Server error"
        --
        _ ->
            BadRequest "Server error"


decodeFormErrors : List String -> Http.Error -> List ( String, List String )
decodeFormErrors fieldNames error =
    let
        fallback =
            [ ( "server", [] ) ]

        fieldDecoder : String -> Decoder ( String, List String )
        fieldDecoder field =
            let
                toDecoder : List String -> Decoder ( String, List String )
                toDecoder errors =
                    Decode.succeed
                        ( field, errors )
            in
            Decode.succeed toDecoder
                |> requiredAt [ "errors", "detail", field ] (list string)
                |> resolve

        decodeField response fieldName =
            response.body
                |> decodeString (fieldDecoder fieldName)
    in
    case error of
        Http.BadStatus response ->
            List.filterMap
                (\x ->
                    case x of
                        Result.Err _ ->
                            Nothing

                        Result.Ok a ->
                            Just a
                )
                (List.map (decodeField response) fieldNames)

        _ ->
            fallback


credStorageKey : String
credStorageKey =
    "cred"


port storeCache : Maybe Value -> Cmd msg


port onStoreChange : (Value -> msg) -> Sub msg


port received401 : () -> Cmd msg


credDecoder : Decoder Cred
credDecoder =
    Decode.succeed Cred
        |> requiredAt [ "user", "name" ] Decode.string
        |> requiredAt [ "user", "email" ] Decode.string
        |> requiredAt [ "user", "token" ] Decode.string


logout : Cmd msg
logout =
    storeCache Nothing


storeCredentials : Cred -> Cmd msg
storeCredentials { name, email, token } =
    let
        json =
            Encode.object
                [ ( "user"
                  , Encode.object
                        [ ( "email", Encode.string email )
                        , ( "token", Encode.string token )
                        , ( "name", Encode.string name )
                        ]
                  )
                ]
    in
    storeCache (Just json)


parseCreds maybeCreds =
    maybeCreds
        |> Maybe.andThen
            (\aCred ->
                case Decode.decodeValue credDecoder aCred of
                    Err _ ->
                        Nothing

                    Ok resolvedCred ->
                        Just resolvedCred
            )


type Error
    = Unauthorized
    | BadRequest String


errorToString : Error -> String
errorToString error =
    case error of
        Unauthorized ->
            "Invalid email or password"

        BadRequest errorText ->
            errorText


handleError : { a | session : Session } -> Error -> Cmd msg
handleError a error =
    case error of
        Unauthorized ->
            Cmd.batch
                [ Route.rerouteTo a (Route.Login Nothing)

                -- , Debug.log "handle" storeCache Nothing
                ]

        _ ->
            Cmd.none
