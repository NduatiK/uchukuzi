module Utils.GroupBy exposing (attr, date)

import Time
import Utils.DateFormatter


date :
    Time.Zone
    -> (a -> Time.Posix)
    -> List a
    -> List ( String, List a )
date timezone getTime list =
    attr
        { groupBy = getTime >> Time.posixToMillis
        , nameAs = getTime >> Utils.DateFormatter.dateFormatter timezone
        , ascending = True
        }
        list


attr :
    { groupBy : a -> comparable
    , nameAs : a -> String
    , ascending : Bool
    }
    -> List a
    -> List ( String, List a )
attr { groupBy, nameAs, ascending } list =
    let
        listWithAttr : List ( String, a )
        listWithAttr =
            List.map (\t -> ( nameAs t, t )) list

        orderedList : List ( String, a )
        orderedList =
            if ascending then
                List.sortBy (\t -> groupBy (Tuple.second t)) listWithAttr

            else
                List.reverse (List.sortBy (\t -> groupBy (Tuple.second t)) listWithAttr)

        groupListByAttr : List ( String, List a ) -> List ( String, a ) -> List ( String, List a )
        groupListByAttr grouped ungrouped =
            let
                remainingList =
                    Maybe.withDefault [] (List.tail ungrouped)
            in
            case ( List.head grouped, List.head ungrouped ) of
                -- there are no more ungrouped list
                ( _, Nothing ) ->
                    grouped

                -- there are no grouped list
                ( Nothing, Just ( label, listItem ) ) ->
                    let
                        newGrouped =
                            [ ( label, [ listItem ] ) ]
                    in
                    groupListByAttr newGrouped remainingList

                -- there are some grouped list
                ( Just ( groupLabel, groupedList ), Just ( label, listItem ) ) ->
                    -- there list is for the same label as the head
                    if groupLabel == label then
                        let
                            newGrouped =
                                case List.tail grouped of
                                    Just tailOfGrouped ->
                                        ( label, listItem :: groupedList ) :: tailOfGrouped

                                    Nothing ->
                                        [ ( label, listItem :: groupedList ) ]
                        in
                        groupListByAttr newGrouped remainingList
                        -- there list is for a different label the head

                    else
                        let
                            newGrouped =
                                ( label, [ listItem ] ) :: grouped
                        in
                        groupListByAttr newGrouped remainingList
    in
    groupListByAttr [] orderedList
