module Utils.GroupByDate exposing (group)

import Time
import Utils.DateFormatter


group : List a -> Time.Zone -> (a -> Time.Posix) -> List ( String, List a )
group list timezone getTime =
    let
        listWithDays : List ( String, a )
        listWithDays =
            List.map (\t -> ( Utils.DateFormatter.dateFormatter timezone (getTime t), t )) list

        orderedList : List ( String, a )
        orderedList =
            List.sortBy (\t -> Time.posixToMillis (getTime (Tuple.second t))) listWithDays

        groupListByMonth : List ( String, List a ) -> List ( String, a ) -> List ( String, List a )
        groupListByMonth grouped ungrouped =
            let
                remainingList =
                    Maybe.withDefault [] (List.tail ungrouped)
            in
            case ( List.head grouped, List.head ungrouped ) of
                -- there are no more ungrouped list
                ( _, Nothing ) ->
                    grouped

                -- there are no grouped list
                ( Nothing, Just ( month, listItem ) ) ->
                    let
                        newGrouped =
                            [ ( month, [ listItem ] ) ]
                    in
                    groupListByMonth newGrouped remainingList

                -- there are some grouped list
                ( Just ( groupMonth, groupedList ), Just ( month, listItem ) ) ->
                    -- there list is for the same month as the head
                    if groupMonth == month then
                        let
                            newGrouped =
                                case List.tail grouped of
                                    Just tailOfGrouped ->
                                        ( month, listItem :: groupedList ) :: tailOfGrouped

                                    Nothing ->
                                        [ ( month, listItem :: groupedList ) ]
                        in
                        groupListByMonth newGrouped remainingList
                        -- there list is for a different month the head

                    else
                        let
                            newGrouped =
                                ( month, [ listItem ] ) :: grouped
                        in
                        groupListByMonth newGrouped remainingList
    in
    groupListByMonth [] orderedList
