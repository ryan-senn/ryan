module Asx200 exposing (main)

import Browser
import Browser.Dom as Dom
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Round
import Task


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = always Sub.none
        }


type alias Flags =
    { data : List Row
    }


type alias Model =
    { groups : Dict Int (List Row)
    , highlighted : Maybe Row
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        initialDict =
            List.range 0 2000
                |> List.map (\i -> ( i, [] ))
                |> Dict.fromList
    in
    ( { groups = List.foldl populateDict initialDict flags.data
      , highlighted = Nothing
      }
    , Dom.getViewportOf "chart"
        |> Task.andThen (\viewport -> Dom.setViewportOf "chart" (viewport.scene.width / 2 - viewport.viewport.width / 2) 0)
        |> Task.attempt (always NoOp)
    )


populateDict : Row -> Dict Int (List Row) -> Dict Int (List Row)
populateDict row acc =
    let
        group =
            row.diff + 1000
    in
    Dict.insert group (row :: (Dict.get group acc |> Maybe.withDefault [])) acc


type alias Row =
    { date : String
    , open : Float
    , close : Float
    , diff : Int
    }


type Msg
    = NoOp
    | Highlight Row
    | Hide


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        Highlight row ->
            ( { model | highlighted = Just row }, Cmd.none )

        Hide ->
            ( { model | highlighted = Nothing }, Cmd.none )


view : Model -> Html Msg
view model =
    div
        []
        [ highlightView model.highlighted
        , div
            [ id "chart" ]
            (Dict.map groupView model.groups |> Dict.values)
        , p
            []
            [ text "Data taken from: "
            , a
                [ class "url", href "https://au.finance.yahoo.com/quote/%5EAXJO/history?period1=713196000&period2=1565186400&interval=1d&filter=history&frequency=1d", target "_blank" ]
                [ text "https://au.finance.yahoo.com/quote/%5EAXJO/history?period1=713196000&period2=1565186400&interval=1d&filter=history&frequency=1d" ]
            ]
        , p
            []
            [ text "Inspired by: "
            , a
                [ class "url", href "https://www.reddit.com/r/AusFinance/comments/cn58z9/visualising_every_single_day_of_the_us_stock/", target "_blank" ]
                [ text "https://www.reddit.com/r/AusFinance/comments/cn58z9/visualising_every_single_day_of_the_us_stock/" ]
            ]
        ]


highlightView : Maybe Row -> Html Msg
highlightView mRow =
    case mRow of
        Just row ->
            div
                [ class "highlight" ]
                [ ul
                    []
                    [ li
                        []
                        [ text <| "Date: " ++ row.date ]
                    , li
                        []
                        [ text <| "Open: " ++ Round.round 2 row.open ]
                    , li
                        []
                        [ text <| "Close: " ++ Round.round 2 row.close ]
                    , li
                        []
                        [ text <| "Change: " ++ percent 0 2 row.diff ]
                    ]
                ]

        Nothing ->
            div
                [ class "highlight" ]
                [ text "Hover/Click dot to show info" ]


groupView : Int -> List Row -> Html Msg
groupView diff rows =
    let
        left =
            diff
                |> (*) 10
                |> String.fromInt
    in
    div
        [ class "group", style "left" (left ++ "px"), classList [ ( "line", modBy 10 diff == 0 ) ] ]
        [ div
            [ class "dots" ]
            (List.map rowView rows)
        , div
            [ class "percent" ]
            [ text <| label diff ]
        ]


label : Int -> String
label diff =
    if modBy 10 diff == 0 then
        percent 1000 1 diff

    else
        ""


rowView : Row -> Html Msg
rowView row =
    div
        [ class "dot"
        , onMouseEnter <| Highlight row
        , onMouseLeave Hide
        ]
        []


percent : Int -> Int -> Int -> String
percent offset precision int =
    (toFloat (int - offset)
        / 100
        |> Round.round precision
    )
        ++ "%"
