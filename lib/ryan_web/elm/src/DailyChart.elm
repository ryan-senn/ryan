module DailyChart exposing (main)

import Browser
import Browser.Dom as Dom
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Round
import Task


percentRange : Int
percentRange =
    30


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
    , maxRows : Int
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        initialDict =
            List.range 0 (percentRange * 200)
                |> List.map (\i -> ( i, [] ))
                |> Dict.fromList

        groups =
            List.foldl populateDict initialDict flags.data

        maxRows_ =
            Dict.foldl maxRows 0 groups
    in
    ( { groups = groups
      , maxRows = maxRows_
      }
    , Dom.getViewportOf "chart"
        |> Task.andThen (\viewport -> Dom.setViewportOf "chart" (viewport.scene.width / 2 - viewport.viewport.width / 2) 0)
        |> Task.attempt (always NoOp)
    )


populateDict : Row -> Dict Int (List Row) -> Dict Int (List Row)
populateDict row acc =
    let
        group =
            row.diff + (percentRange * 100)
    in
    Dict.insert group (row :: (Dict.get group acc |> Maybe.withDefault [])) acc


maxRows : Int -> List Row -> Int -> Int
maxRows _ rows acc =
    let
        lenght =
            List.length rows
    in
    if lenght > acc then
        lenght

    else
        acc


type alias Row =
    { date : String
    , open : Float
    , close : Float
    , diff : Int
    }


type Msg
    = NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    ( model, Cmd.none )


view : Model -> Html Msg
view model =
    div
        []
        [ div
            [ class "chart-placeholder", height model.maxRows]
            [ div
                [ class "chart-container", height model.maxRows ]
                [ div
                    [ id "chart", height model.maxRows ]
                    (Dict.map (groupView model) model.groups |> Dict.values)
                ]
            ]
        , p
            []
            [ text "Inspired by: "
            , a
                [ class "url", href "https://www.reddit.com/r/AusFinance/comments/cn58z9/visualising_every_single_day_of_the_us_stock/", target "_blank" ]
                [ text "https://www.reddit.com/r/AusFinance/comments/cn58z9/visualising_every_single_day_of_the_us_stock/" ]
            ]
        ]


groupView : Model -> Int -> List Row -> Html Msg
groupView model diff rows =
    let
        left =
            diff
                |> (*) 10
                |> String.fromInt
    in
    div
        [ class "group", style "left" (left ++ "px"), height <| model.maxRows - 5 ]
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
        percent (percentRange * 100) 1 diff

    else
        ""


rowView : Row -> Html Msg
rowView row =
    div
        [ class "dot" ]
        [ div
            [ class "info" ]
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
        ]


percent : Int -> Int -> Int -> String
percent offset precision int =
    (toFloat (int - offset)
        / 100
        |> Round.round precision
    )
        ++ "%"


height : Int -> Attribute Msg
height maxRows_ =
    style "height" <| String.fromInt ((maxRows_ + 7) * 9) ++ "px"
