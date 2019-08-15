module Powerball exposing (main)

import Array exposing (Array)
import Browser
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Lazy exposing (..)
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
        , subscriptions = always Sub.none
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
    { userEntry : UserEntry
    , userCombination : Maybe Combination
    , draw : Maybe Combination
    , budget : Int
    , spent : Int
    , won : Int
    , winningDraws : List ( Combination, Combination )
    , showWinningDraws : Bool
    , hasClickedPlay : Bool
    , isPlaying : Bool
    , speed : Int
    }


init : Model
init =
    { userEntry = initialUserEntry
    , userCombination = Nothing
    , draw = Nothing
    , budget = 0
    , spent = 0
    , won = 0
    , winningDraws = []
    , showWinningDraws = True
    , hasClickedPlay = False
    , isPlaying = False
    , speed = 10
    }


type alias UserEntry =
    { numbers : Array String
    , powerball : String
    }


initialUserEntry : UserEntry
initialUserEntry =
    { numbers = Array.repeat 7 ""
    , powerball = ""
    }


type alias Combination =
    { numbers : Set Int
    , powerball : Int
    }


type Msg
    = UpdateNumber Int String
    | UpdatePowerball String
    | GenerateUserCombination
    | FillUserCombination Combination
    | Play Int
    | DelayRound Combination
    | RunRound Combination Combination
    | SetSpeed Int
    | ToggleWinningDraws


update : Msg -> Model -> ( Model, Cmd Msg )
update msg ({ userEntry } as model) =
    case msg of
        UpdateNumber index value ->
            ( { model
                | userEntry = { userEntry | numbers = Array.set index value userEntry.numbers }
                , userCombination = Nothing
              }
            , Cmd.none
            )

        UpdatePowerball value ->
            ( { model
                | userEntry = { userEntry | powerball = value }
                , userCombination = Nothing
              }
            , Cmd.none
            )

        GenerateUserCombination ->
            ( model, Random.generate FillUserCombination combinationGenerator )

        FillUserCombination userCombination ->
            ( { model
                | userCombination = Just userCombination
                , userEntry =
                    UserEntry
                        (userCombination.numbers |> Set.toList |> Array.fromList |> Array.map String.fromInt)
                        (String.fromInt userCombination.powerball)
              }
            , Cmd.none
            )

        Play budget ->
            let
                userCombination =
                    case model.userCombination of
                        Just combination ->
                            Just combination

                        Nothing ->
                            validateUserEntry model.userEntry
            in
            case userCombination of
                Just userCombination_ ->
                    ( { model
                        | userCombination = Just userCombination_
                        , hasClickedPlay = True
                        , isPlaying = True
                        , budget = model.budget + budget
                      }
                    , if not model.isPlaying then
                        Random.generate (RunRound userCombination_) combinationGenerator

                      else
                        Cmd.none
                    )

                Nothing ->
                    ( { model | hasClickedPlay = True }, Cmd.none )

        DelayRound userCombination ->
            ( model, Random.generate (RunRound userCombination) combinationGenerator )

        RunRound userCombination draw ->
            runRound userCombination draw model

        SetSpeed speed ->
            ( { model | speed = speed }, Cmd.none )

        ToggleWinningDraws ->
            ( { model | showWinningDraws = not model.showWinningDraws }, Cmd.none )


runRound : Combination -> Combination -> Model -> ( Model, Cmd Msg )
runRound userCombination draw model =
    if model.spent + costPerEntry - model.won > model.budget then
        ( { model | isPlaying = False, draw = Nothing }, Cmd.none )

    else
        let
            won =
                prize userCombination draw
        in
        ( { model
            | draw = Just draw
            , spent = model.spent + costPerEntry
            , won = model.won + won
            , winningDraws =
                if won > 0 then
                    ( userCombination, draw ) :: model.winningDraws

                else
                    model.winningDraws
          }
        , Process.sleep (toFloat (1000 // model.speed))
            |> Task.perform (always <| DelayRound userCombination)
        )


prize : Combination -> Combination -> Int
prize userCombination draw =
    let
        matchingNumbers_ =
            userCombination.numbers
                |> Set.intersect draw.numbers
                |> Set.size

        matchingPowerball =
            if userCombination.powerball == draw.powerball then
                1

            else
                0
    in
    prizes
        |> Dict.get ( matchingNumbers_, matchingPowerball )
        |> Maybe.map Tuple.first
        |> Maybe.withDefault 0


combinationGenerator : Generator Combination
combinationGenerator =
    let
        numbers =
            Random.int 1 35
                |> Random.andThen (numbersGenerator Set.empty)

        powerball =
            Random.int 1 20
    in
    Random.map2 Combination numbers powerball


numbersGenerator : Set Int -> Int -> Generator (Set Int)
numbersGenerator set number =
    if Set.size set < 6 || Set.member number set then
        Random.int 1 35
            |> Random.andThen (numbersGenerator (Set.insert number set))

    else
        Random.constant (Set.insert number set)


validateUserEntry : UserEntry -> Maybe Combination
validateUserEntry userEntry =
    let
        validatedNumbers =
            userEntry.numbers
                |> Array.foldl validateUserEntryHelp Set.empty

        validatedPowerball =
            validateUserNumber Powerball userEntry.powerball
    in
    case ( Set.size validatedNumbers, validatedPowerball ) of
        ( 7, Just powerball ) ->
            Just <| Combination validatedNumbers powerball

        _ ->
            Nothing


validateUserEntryHelp : String -> Set Int -> Set Int
validateUserEntryHelp number set =
    case validateUserNumber Regular number of
        Just int ->
            Set.insert int set

        Nothing ->
            set


validateUserNumber : NumberType -> String -> Maybe Int
validateUserNumber numberType number =
    case String.toInt number of
        Just int ->
            if numberType == Regular && int >= 1 && int <= 35 then
                Just int

            else if numberType == Powerball && int >= 1 && int <= 20 then
                Just int

            else
                Nothing

        _ ->
            Nothing


view : Model -> Html Msg
view ({ draw, spent, won, budget, hasClickedPlay, speed } as model) =
    div
        []
        [ div
            [ class "title-with-button" ]
            [ h3
                []
                [ text "Pick your numbers" ]
            , button
                [ onClick GenerateUserCombination ]
                [ text "Random" ]
            ]
        , if model.isPlaying then
            combinationView model.draw model.userCombination

          else
            userEntryView model
        , h3
            []
            [ text "Winning numbers" ]
        , combinationView model.userCombination model.draw
        , div
            [ class "speed" ]
            [ p
                []
                [ text "Draws per second:" ]
            , label
                []
                [ input
                    [ type_ "radio", onClick <| SetSpeed 1, checked <| speed == 1 ]
                    []
                , text "1"
                ]
            , label
                []
                [ input
                    [ type_ "radio", onClick <| SetSpeed 10, checked <| speed == 10 ]
                    []
                , text "10"
                ]
            , label
                []
                [ input
                    [ type_ "radio", onClick <| SetSpeed 100, checked <| speed == 100 ]
                    []
                , text "100"
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
        , table
            [ class "result" ]
            [ tr
                []
                [ th
                    []
                    [ text "Spent" ]
                , td
                    []
                    [ text <| displayDollars spent ]
                ]
            , tr
                []
                [ th
                    []
                    [ text "Won" ]
                , td
                    []
                    [ text <| displayDollars won ]
                ]
            , tr
                []
                [ th
                    []
                    [ text "Win/Loss" ]
                , td
                    []
                    [ text <| displayDollars (won - spent) ]
                ]
            , tr
                []
                [ th
                    []
                    [ text "Balance" ]
                , td
                    []
                    [ text <| displayDollars (budget - spent + won) ]
                ]
            ]
        , lazy2 winningDrawsView model.showWinningDraws model.winningDraws
        , h3
            [ class "prizes" ]
            [ text "Prizes (from Draw 1209, 18 July 2019)" ]
        , prizesView
        , p
            []
            [ text "Inspired by: "
            , a
                [ class "url", href "https://www.reddit.com/r/AusFinance/comments/cgohom/lottery_calculator/", target "_blank" ]
                [ text "https://www.reddit.com/r/AusFinance/comments/cgohom/lottery_calculator/" ]
            ]
        ]


userEntryView : Model -> Html Msg
userEntryView ({ userEntry, hasClickedPlay, isPlaying } as model) =
    div
        [ class "numbers" ]
        ((userEntry.numbers
            |> Array.indexedMap
                (\index value ->
                    numberInput model Regular (UpdateNumber index) value
                )
            |> Array.toList
         )
            ++ [ numberInput model Powerball UpdatePowerball userEntry.powerball ]
        )


numberInput : Model -> NumberType -> (String -> Msg) -> String -> Html Msg
numberInput model numberType msg value_ =
    input
        [ type_ "text"
        , onInput msg
        , value value_
        , maxlength 2
        , class "number"
        , classList
            [ ( "powerball", numberType == Powerball )
            , ( "invalid", isNumberInputInvalid model numberType value_ && model.hasClickedPlay )
            , ( "playing", model.isPlaying )
            ]
        ]
        []


isNumberInputInvalid : Model -> NumberType -> String -> Bool
isNumberInputInvalid model numberType value =
    case ( numberType, validateUserNumber numberType value ) of
        ( Regular, Just _ ) ->
            model.userEntry.numbers
                |> Array.filter ((==) value)
                |> Array.length
                |> (<) 1

        ( Powerball, Just _ ) ->
            False

        _ ->
            True


combinationView : Maybe Combination -> Maybe Combination -> Html Msg
combinationView combination1 combination2 =
    case ( combination1, combination2 ) of
        ( Just combination1_, Just combination2_ ) ->
            div
                [ class "numbers" ]
                ((combination2_.numbers
                    |> Set.toList
                    |> List.map (\number -> combinationNumber (Set.member number combination1_.numbers) Regular (Just number))
                 )
                    ++ [ combinationNumber (combination1_.powerball == combination2_.powerball) Powerball (Just combination2_.powerball) ]
                )

        _ ->
            div
                [ class "numbers" ]
                ((List.repeat 7 Nothing
                    |> List.map (combinationNumber False Regular)
                 )
                    ++ [ combinationNumber False Powerball Nothing ]
                )


combinationNumber : Bool -> NumberType -> Maybe Int -> Html Msg
combinationNumber isMatch numberType mNumber =
    div
        [ class "number"
        , classList
            [ ( "powerball", numberType == Powerball )
            , ( "match", isMatch )
            ]
        ]
        [ text (mNumber |> Maybe.map String.fromInt |> Maybe.withDefault "") ]


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


winningDrawsView : Bool -> List ( Combination, Combination ) -> Html Msg
winningDrawsView isShown winningDraws =
    div
        [ class "winning-draws" ]
        [ button
            [ class "button button-clear"
            , onClick ToggleWinningDraws
            ]
            [ text <| if isShown then "Hide winning draws " else "Show winning draws "
            , span
                [ class <|
                    if isShown then
                        "fa fa-arrow-up"

                    else
                        "fa fa-arrow-down"
                ]
                []
            ]
        , if isShown then
            div
                []
                (List.map winningDrawView winningDraws)

          else
            text ""
        ]



winningDrawView : (Combination, Combination) -> Html Msg
winningDrawView (userCombination, draw) =
    div
        [ class "winning-draw" ]
        [ combinationView (Just userCombination) (Just draw)
        , div
            []
            [ text <| "+ " ++ (prize userCombination draw |> displayDollars) ]
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
