module Powerball exposing (main)

import Array exposing (Array)
import Browser
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Process
import Random exposing (Generator)
import Set exposing (Set)
import Task


main : Program {} Model Msg
main =
    Browser.element
        { init = always ( init, Cmd.none )
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- Note: all values are in cents


costPerEntry : Int
costPerEntry =
    100


prizes : Dict ( Int, Int ) ( Int, Int )
prizes =
    Dict.empty
        |> Dict.insert ( 7, 1 ) ( 3666666667, 134490400 )
        |> Dict.insert ( 7, 0 ) ( 4927610, 7078443 )
        |> Dict.insert ( 6, 1 ) ( 398385, 686176 )
        |> Dict.insert ( 6, 0 ) ( 41095, 36115 )
        |> Dict.insert ( 5, 1 ) ( 14310, 16943 )
        |> Dict.insert ( 5, 0 ) ( 4000, 892 )
        |> Dict.insert ( 4, 1 ) ( 6640, 1173 )
        |> Dict.insert ( 3, 1 ) ( 1680, 188 )
        |> Dict.insert ( 2, 1 ) ( 1035, 66 )


type NumberType
    = Regular
    | Powerball


type alias Model =
    { selection : Selection
    , draw : Maybe Draw
    , budget : Int
    , spent : Int
    , won : Int
    , hasClickedPlay : Bool
    , isPlaying : Bool
    , speed : Int
    }


init : Model
init =
    { selection = initialSelection
    , draw = Nothing
    , budget = 0
    , spent = 0
    , won = 0
    , hasClickedPlay = False
    , isPlaying = False
    , speed = 10
    }


type alias Selection =
    { numbers : Array String
    , powerball : String
    }


initialSelection : Selection
initialSelection =
    { numbers = Array.repeat 7 ""
    , powerball = ""
    }


type alias Draw =
    { numbers : Set Int
    , powerball : Int
    }


type Msg
    = UpdateNumber Int String
    | UpdatePowerball String
    | RandomPick
    | FillSelection Draw
    | Play Int
    | DelayRound
    | RunRound Draw
    | SetSpeed Int


update : Msg -> Model -> ( Model, Cmd Msg )
update msg ({ selection } as model) =
    case msg of
        UpdateNumber index value ->
            ( { model | selection = { selection | numbers = Array.set index value selection.numbers } }, Cmd.none )

        UpdatePowerball value ->
            ( { model | selection = { selection | powerball = value } }, Cmd.none )

        RandomPick ->
            ( model, Random.generate FillSelection drawGenerator )

        FillSelection draw ->
            ( { model | selection = drawToSelection draw }, Cmd.none )

        Play budget ->
            if isSelectionValid model.selection then
                ( { model | hasClickedPlay = True, isPlaying = True, budget = model.budget + budget }
                , if not model.isPlaying then
                    Random.generate RunRound drawGenerator

                  else
                    Cmd.none
                )

            else
                ( { model | hasClickedPlay = True }, Cmd.none )

        DelayRound ->
            ( model, Random.generate RunRound drawGenerator )

        RunRound draw ->
            runRound draw model

        SetSpeed speed ->
            ( { model | speed = speed }, Cmd.none )


runRound : Draw -> Model -> ( Model, Cmd Msg )
runRound draw model =
    if model.spent + costPerEntry - model.won > model.budget then
        ( { model | isPlaying = False }, Cmd.none )

    else
        ( { model
            | draw = Just draw
            , spent = model.spent + costPerEntry
            , won = model.won + prize model.selection draw
          }
        , Process.sleep (toFloat (1000 // model.speed))
            |> Task.perform (always DelayRound)
        )


prize : Selection -> Draw -> Int
prize selection draw =
    let
        matchingNumbers_ =
            draw
                |> drawToSelection
                |> matchingNumbers selection
                |> List.length

        matchingPowerball =
            if selection.powerball == String.fromInt draw.powerball then
                1

            else
                0
    in
    prizes
        |> Dict.get ( matchingNumbers_, matchingPowerball )
        |> Maybe.map Tuple.first
        |> Maybe.withDefault 0


matchingNumbers : Selection -> Selection -> List String
matchingNumbers selection1 selection2 =
    selection1.numbers
        |> Array.toList
        |> List.filter (\number -> List.member number (Array.toList selection2.numbers))


drawToSelection : Draw -> Selection
drawToSelection draw =
    { numbers = draw.numbers |> Set.toList |> Array.fromList |> Array.map String.fromInt
    , powerball = String.fromInt draw.powerball
    }


drawGenerator : Generator Draw
drawGenerator =
    let
        numbers =
            Random.int 1 35
                |> Random.andThen (numbersGenerator Set.empty)

        powerball =
            Random.int 1 20
    in
    Random.map2 Draw numbers powerball


numbersGenerator : Set Int -> Int -> Generator (Set Int)
numbersGenerator set number =
    if Set.size set < 6 || Set.member number set then
        Random.int 1 35
            |> Random.andThen (numbersGenerator (Set.insert number set))

    else
        Random.constant (Set.insert number set)


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


view : Model -> Html Msg
view ({ selection, draw, spent, won, budget, hasClickedPlay, speed } as model) =
    div
        []
        [ h3
            []
            [ text "Pick your numbers" ]
        , selectionView model
        , button
            [ onClick RandomPick ]
            [ text "Pick for me" ]
        , h3
            []
            [ text "Winning numbers" ]
        , drawView model
        , div
            [ class "speed" ]
            [ label
                []
                [ input
                    [ type_ "radio", onClick <| SetSpeed 1, checked <| speed == 1 ]
                    []
                , text "1 draw per second"
                ]
            , label
                []
                [ input
                    [ type_ "radio", onClick <| SetSpeed 10, checked <| speed == 10 ]
                    []
                , text "10 draws per second"
                ]
            , label
                []
                [ input
                    [ type_ "radio", onClick <| SetSpeed 100, checked <| speed == 100 ]
                    []
                , text "100 draws per second"
                ]
            ]
        , div
            [ class "play" ]
            [ button
                [ onClick <| Play 10000 ]
                [ text "Throw in $100" ]
            , button
                [ onClick <| Play 100000 ]
                [ text "Throw in $1000" ]
            ]
        , h3
            []
            [ text "Result" ]
        , div
            []
            [ text <| "Spent: " ++ displayDollars spent ]
        , div
            []
            [ text <| "Won: " ++ displayDollars won ]
        , div
            []
            [ text <| "Win/Loss: " ++ displayDollars (won - spent) ]
        , div
            []
            [ text <| "Balance: " ++ displayDollars (budget - spent + won) ]
        , h3
            [ class "prizes" ]
            [ text "Prizes (from Draw 1209, 18 July 2019)" ]
        , prizesView
        ]


selectionView : Model -> Html Msg
selectionView { hasClickedPlay, selection, draw } =
    div
        [ class "numbers" ]
        ((selection.numbers
            |> Array.indexedMap (\index value -> numberInput hasClickedPlay draw Regular (UpdateNumber index) value)
            |> Array.toList
         )
            ++ [ numberInput hasClickedPlay draw Powerball UpdatePowerball selection.powerball ]
        )


numberInput : Bool -> Maybe Draw -> NumberType -> (String -> Msg) -> String -> Html Msg
numberInput hasClickedPlay mDraw numberType msg value_ =
    let
        powerballMatch =
            numberType == Powerball && Maybe.map (.powerball >> String.fromInt) mDraw == Just value_

        numberMatch =
            numberType == Regular && (Maybe.map (.numbers >> Set.toList >> List.map String.fromInt >> List.member value_) mDraw |> Maybe.withDefault False)
    in
    input
        [ type_ "text"
        , onInput msg
        , value value_
        , maxlength 2
        , class "number"
        , classList
            [ ( "powerball", numberType == Powerball )
            , ( "invalid", isInvalid numberType value_ && hasClickedPlay )
            , ( "match", powerballMatch || numberMatch )
            ]
        ]
        []


drawView : Model -> Html Msg
drawView { selection, draw, hasClickedPlay } =
    case draw of
        Just draw_ ->
            div
                [ class "numbers" ]
                ((draw_.numbers
                    |> Set.toList
                    |> List.map String.fromInt
                    |> List.map (drawNumber hasClickedPlay selection Regular)
                 )
                    ++ [ drawNumber hasClickedPlay selection Powerball (String.fromInt draw_.powerball) ]
                )

        Nothing ->
            div
                [ class "numbers" ]
                ((List.repeat 7 ""
                    |> List.map (drawNumber hasClickedPlay selection Regular)
                 )
                    ++ [ drawNumber hasClickedPlay selection Powerball "" ]
                )


drawNumber : Bool -> Selection -> NumberType -> String -> Html Msg
drawNumber hasClickedPlay selection numberType value =
    div
        [ class "number"
        , classList
            [ ( "powerball", numberType == Powerball )
            , ( "match"
              , if not hasClickedPlay || not (isSelectionValid selection) then
                    False

                else if numberType == Powerball then
                    selection.powerball == value

                else
                    selection.numbers
                        |> Array.toList
                        |> List.member value
              )
            ]
        ]
        [ text value ]


prizesView : Html Msg
prizesView =
    Html.table
        []
        ([ tr
            []
            [ td
                []
                [ text "Match" ]
            , td
                []
                [ text "Odds (1 in...)" ]
            , td
                []
                [ text "Prize" ]
            ]
         ]
            ++ (prizes
                    |> Dict.toList
                    |> List.sortBy (\( _, ( _, odds ) ) -> odds)
                    |> List.map prizeRow
                    |> List.reverse
               )
        )


prizeRow : ( ( Int, Int ), ( Int, Int ) ) -> Html Msg
prizeRow ( ( matchingNumbers_, matchingPowerball ), ( prize_, odds ) ) =
    tr
        []
        [ td
            []
            [ text <|
                String.fromInt matchingNumbers_
                    ++ " Numbers"
                    ++ (if matchingPowerball == 0 then
                            ""

                        else
                            " + Powerball"
                       )
            ]
        , td
            []
            [ text <| String.fromInt odds ]
        , td
            []
            [ text <| displayDollars prize_ ]
        ]


displayDollars : Int -> String
displayDollars cents =
    let
        dollars =
            toFloat cents / 100 |> abs |> String.fromFloat
    in
    if cents < 0 then
        "-$" ++ dollars

    else
        "$" ++ dollars


isSelectionValid : Selection -> Bool
isSelectionValid selection =
    let
        areNumbersValid =
            selection.numbers
                |> Array.filter (isInvalid Regular)
                |> Array.length
                |> (==) 0

        isPowerballValid =
            selection.powerball
                |> isInvalid Powerball
                |> not
    in
    areNumbersValid && isPowerballValid


isInvalid : NumberType -> String -> Bool
isInvalid numberType number =
    case String.toInt number of
        Just int ->
            (numberType == Powerball && (int < 1 || int > 20))
                || (numberType == Regular && (int < 1 || int > 35))

        Nothing ->
            True
