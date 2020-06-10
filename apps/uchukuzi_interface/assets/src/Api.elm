port module Api exposing (..)

import Api.Endpoint as Endpoint exposing (Endpoint)
import Http exposing (Body)
import Json.Decode as Decode exposing (Decoder, Value, string)
import Json.Decode.Pipeline exposing (required, requiredAt, resolve)
import Json.Encode as Encode
import Models.Location exposing (Location, locationDecoder)
import Navigation exposing (LoginRedirect, Route)
import RemoteData exposing (RemoteData(..), WebData)
import Session exposing (Credentials, Session)


delete : Session -> Endpoint -> Decoder a -> Cmd (WebData a)
delete session url decoder =
    Endpoint.delete url session decoder


get : Session -> Endpoint -> Decoder a -> Cmd (WebData a)
get session url decoder =
    Endpoint.get url session decoder


post : Session -> Endpoint -> Encode.Value -> Decoder a -> Cmd (WebData a)
post session url body decoder =
    Endpoint.post url session (body |> Http.jsonBody) decoder


patch : Session -> Endpoint -> Encode.Value -> Decoder a -> Cmd (WebData a)
patch session url body decoder =
    Endpoint.patch url
        session
        (body |> Http.jsonBody)
        decoder


credStorageKey : String
credStorageKey =
    "cred"


port storeCache : Maybe Value -> Cmd msg


port onStoreChange : (Maybe Value -> msg) -> Sub msg


credDecoder : Decoder Credentials
credDecoder =
    Decode.succeed Credentials
        |> requiredAt [ "name" ] Decode.string
        |> requiredAt [ "email" ] Decode.string
        |> requiredAt [ "token" ] Decode.string
        |> requiredAt [ "school_id" ] Decode.int


credEncoder : Credentials -> Value
credEncoder { name, email, token, school_id } =
    Encode.object
        [ ( "email", Encode.string email )
        , ( "token", Encode.string token )
        , ( "name", Encode.string name )
        , ( "school_id", Encode.int school_id )
        ]


type alias SuccessfulLogin =
    { location : Location
    , creds : Session.Credentials
    }


logout : Cmd msg
logout =
    Cmd.batch
        [ storeCache Nothing
        , Models.Location.clearSchoolLocation
        ]


loginDecoder =
    Decode.succeed SuccessfulLogin
        |> required "location" locationDecoder
        |> required "creds" credDecoder


storeCredentials : Credentials -> Cmd msg
storeCredentials cred =
    storeCache (Just (credEncoder cred))


parseCreds : Maybe Value -> Maybe Credentials
parseCreds maybeCreds =
    maybeCreds
        |> Maybe.andThen
            (\aCredentials ->
                case Decode.decodeValue credDecoder aCredentials of
                    Err e ->
                        Nothing

                    Ok resolvedCredentials ->
                        Just resolvedCredentials
            )
