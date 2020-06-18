module Utils.DateParser exposing (fromDateString)

import Date exposing (..)
import Parser exposing ((|.), (|=), Parser)
import Time exposing (Month(..), Weekday(..))



-- FROM STRING


{-| Attempt to create a date from a string in dd-MM-yyyy format.

    import Date exposing (fromCalendarDate)
    import Utils.DateParser exposing (fromDateString)
    import Time exposing (Month(..), Weekday(..))

    -- calendar date
    fromDateString "26-09-2018"
        == Ok (fromCalendarDate 2018 Sep 26)

The string must represent a valid date; unlike `fromCalendarDate` and
friends, any out-of-range values will fail to produce a date.

    fromDateString "29-02-2018"
        == Err "Invalid calendar date (2018, 2, 29)"

-}
fromDateString : String -> Result String Date
fromDateString =
    Parser.run
        (Parser.succeed identity
            |= parser
            |. (Parser.oneOf
                    [ Parser.map Ok
                        Parser.end
                    , Parser.map (always (Err "Expected a date only, not a date and time"))
                        (Parser.chompIf ((==) 'T'))
                    , Parser.succeed (Err "Expected a date only")
                    ]
                    |> Parser.andThen resultToParser
               )
        )
        >> Result.mapError (List.map deadEndToString >> String.join "; ")


deadEndToString : Parser.DeadEnd -> String
deadEndToString { problem } =
    case problem of
        Parser.Problem message ->
            message

        _ ->
            "Expected a date in dd-MM-yyyy format"


resultToParser : Result String a -> Parser a
resultToParser result =
    case result of
        Ok x ->
            Parser.succeed x

        Err message ->
            Parser.problem message



-- day of year


type DayOfYear
    = DayAndMonth Int Int


fromDayOfYearAndYear : ( DayOfYear, Int ) -> Result String Date
fromDayOfYearAndYear ( DayAndMonth d mn, y ) =
    fromCalendarParts y mn d



-- parser


parser : Parser Date
parser =
    Parser.succeed Tuple.pair
        |= dayOfYear
        |. Parser.token "-"
        |= int4
        |> Parser.andThen
            (fromDayOfYearAndYear >> resultToParser)


dayOfYear : Parser DayOfYear
dayOfYear =
    Parser.succeed DayAndMonth
        |= int1or2
        |. Parser.token "-"
        |= int1or2
        |> Parser.andThen Parser.commit


int4 : Parser Int
int4 =
    Parser.succeed ()
        |. Parser.oneOf
            [ Parser.chompIf (\c -> c == '-')
            , Parser.succeed ()
            ]
        |. Parser.chompIf Char.isDigit
        |. Parser.chompIf Char.isDigit
        |. Parser.chompIf Char.isDigit
        |. Parser.chompIf Char.isDigit
        |> Parser.mapChompedString
            (\str _ -> String.toInt str |> Maybe.withDefault 0)


int1or2 : Parser Int
int1or2 =
    Parser.succeed ()
        |. Parser.chompIf Char.isDigit
        |. Parser.oneOf
            [ Parser.chompIf Char.isDigit
            , Parser.succeed ()
            ]
        |> Parser.mapChompedString
            (\str _ -> String.toInt str |> Maybe.withDefault 0)


fromCalendarParts : Int -> Int -> Int -> Result String Date
fromCalendarParts y mn d =
    if
        (mn |> isBetweenInt 1 12)
            && (d |> isBetweenInt 1 (daysInMonth y (mn |> numberToMonth)))
    then
        Ok <| Date.fromRataDie <| daysBeforeYear y + daysBeforeMonth y (mn |> numberToMonth) + d

    else
        Err <| "Invalid calendar date (" ++ String.fromInt y ++ ", " ++ String.fromInt mn ++ ", " ++ String.fromInt d ++ ")"


isBetweenInt : Int -> Int -> Int -> Bool
isBetweenInt a b x =
    a <= x && x <= b


daysInMonth : Int -> Month -> Int
daysInMonth y m =
    case m of
        Jan ->
            31

        Feb ->
            if isLeapYear y then
                29

            else
                28

        Mar ->
            31

        Apr ->
            30

        May ->
            31

        Jun ->
            30

        Jul ->
            31

        Aug ->
            31

        Sep ->
            30

        Oct ->
            31

        Nov ->
            30

        Dec ->
            31


daysBeforeMonth : Int -> Month -> Int
daysBeforeMonth y m =
    let
        leapDays =
            if isLeapYear y then
                1

            else
                0
    in
    case m of
        Jan ->
            0

        Feb ->
            31

        Mar ->
            59 + leapDays

        Apr ->
            90 + leapDays

        May ->
            120 + leapDays

        Jun ->
            151 + leapDays

        Jul ->
            181 + leapDays

        Aug ->
            212 + leapDays

        Sep ->
            243 + leapDays

        Oct ->
            273 + leapDays

        Nov ->
            304 + leapDays

        Dec ->
            334 + leapDays


isLeapYear : Int -> Bool
isLeapYear y =
    modBy 4 y == 0 && modBy 100 y /= 0 || modBy 400 y == 0


daysBeforeYear : Int -> Int
daysBeforeYear y1 =
    let
        y =
            y1 - 1

        leapYears =
            floorDiv y 4 - floorDiv y 100 + floorDiv y 400
    in
    365 * y + leapYears


floorDiv : Int -> Int -> Int
floorDiv a b =
    Basics.floor (toFloat a / toFloat b)
