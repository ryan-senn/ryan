module GoldLotto exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Lazy exposing (..)
import Json.Decode as Decode exposing (Decoder)
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


type Game
    = GoldLottoSat
    | GoldLottoMonWed
    | OzLotto


type GameMode
    = Standard
    | Pick Int
    | System Int


type alias Draw =
    { numbers : Set Int
    , supps : Set Int
    }


type alias Model =
    { game : Game
    , gameMode : GameMode
    , speed : Int
    , userSelection : Set Int
    , draw : Draw
    , winningDraws : List WinningDraw
    , showWinningDraws : Bool
    , isPlaying : Bool
    , balance : Int
    , spent : Int
    , won : Int
    }


init : Model
init =
    { game = GoldLottoSat
    , gameMode = Standard
    , speed = 10
    , userSelection = Set.empty
    , draw = Draw Set.empty Set.empty
    , winningDraws = []
    , showWinningDraws = True
    , isPlaying = False
    , balance = 0
    , spent = 0
    , won = 0
    }


type Msg
    = SetGameMode GameMode
    | SetSpeed Int
    | ToggleNumber Int
    | GenerateUserSelection
    | FillUserSelection (Set Int)
    | ClearUserSelection
    | Add Int
    | DelayRound (Set Int)
    | RunRound (Set Int) Draw
    | ToggleWinningDraws


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SetGameMode gameMode ->
            ( { model | gameMode = gameMode, userSelection = Set.empty }, Cmd.none )

        SetSpeed speed ->
            ( { model | speed = speed }, Cmd.none )

        ToggleNumber number ->
            ( { model | userSelection = toggleSet number model.userSelection, isPlaying = False }, Cmd.none )

        GenerateUserSelection ->
            ( model, Random.generate FillUserSelection (numbersGenerator <| numbersForGameMode model.gameMode) )

        FillUserSelection numbers ->
            ( { model | userSelection = numbers, isPlaying = False }, Cmd.none )

        ClearUserSelection ->
            ( { model | userSelection = Set.empty, isPlaying = False }, Cmd.none )

        Add cents ->
            if numbersForGameMode model.gameMode == Set.size model.userSelection then
                ( { model
                    | balance = model.balance + cents
                    , isPlaying = True
                  }
                , if not model.isPlaying then
                    Random.generate (RunRound model.userSelection) drawGenerator

                  else
                    Cmd.none
                )

            else
                ( { model | balance = model.balance + cents }, Cmd.none )

        DelayRound userSelection ->
            ( model, Random.generate (RunRound userSelection) drawGenerator )

        RunRound userSelection draw ->
            if numbersForGameMode model.gameMode == Set.size model.userSelection then
                runRound userSelection draw model

            else
                ( model, Cmd.none )

        ToggleWinningDraws ->
            ( { model | showWinningDraws = not model.showWinningDraws }, Cmd.none )


runRound : Set Int -> Draw -> Model -> ( Model, Cmd Msg )
runRound userSelection draw model =
    if model.spent + gameModeEntryCost model.game model.gameMode - model.won > model.balance then
        ( { model | isPlaying = False, draw = Draw Set.empty Set.empty }, Cmd.none )

    else
        let
            won =
                prize model.game model.gameMode userSelection draw
        in
        ( { model
            | draw = draw
            , spent = model.spent + gameModeEntryCost model.game model.gameMode
            , won = model.won + won
            , winningDraws =
                if won > 0 then
                    WinningDraw userSelection draw model.gameMode :: model.winningDraws

                else
                    model.winningDraws
          }
        , Process.sleep (toFloat (1000 // model.speed))
            |> Task.perform (always <| DelayRound userSelection)
        )


numbersGenerator : Int -> Generator (Set Int)
numbersGenerator size =
    Random.int 1 45
        |> Random.andThen (numbersGeneratorHelp size Set.empty)


numbersGeneratorHelp : Int -> Set Int -> Int -> Generator (Set Int)
numbersGeneratorHelp size set number =
    if Set.size set < size || Set.member number set then
        Random.int 1 45
            |> Random.andThen (numbersGeneratorHelp size (Set.insert number set))

    else
        Random.constant set


drawGenerator : Generator Draw
drawGenerator =
    Random.int 1 45
        |> Random.andThen (drawGeneratorHelp (Draw Set.empty Set.empty))


drawGeneratorHelp : Draw -> Int -> Generator Draw
drawGeneratorHelp draw number =
    Random.int 1 45
        |> Random.andThen
            (if Set.member number <| Set.union draw.numbers draw.supps then
                drawGeneratorHelp draw

             else if Set.size draw.numbers < 6 then
                drawGeneratorHelp { draw | numbers = Set.insert number draw.numbers }

             else if Set.size draw.supps < 2 then
                drawGeneratorHelp { draw | supps = Set.insert number draw.supps }

             else
                always <| Random.constant draw
            )


view : Model -> Html Msg
view model =
    div
        []
        [ div
            [ class "line" ]
            [ label
                [ class "label" ]
                [ text "Game Mode " ]
            , select
                [ on "change" (Decode.map (stringToGameMode >> SetGameMode) targetValue) ]
                (List.map (gameModeOption model.gameMode) (gameEntryCosts model.game))
            ]
        , div
            [ class "line" ]
            [ label
                [ class "label" ]
                [ text "Draws per second" ]
            , div
                [ class "button-group" ]
                [ button
                    [ classList [ ( "is-active", model.speed == 1 ) ]
                    , onClick <| SetSpeed 1
                    ]
                    [ text "1" ]
                , button
                    [ classList [ ( "is-active", model.speed == 10 ) ]
                    , onClick <| SetSpeed 10
                    ]
                    [ text "10" ]
                , button
                    [ classList [ ( "is-active", model.speed == 100 ) ]
                    , onClick <| SetSpeed 100
                    ]
                    [ text "100" ]
                ]
            ]
        , div
            [ class "line" ]
            [ label
                []
                [ text "Pick your numbers" ]
            , button
                [ onClick GenerateUserSelection ]
                [ span
                    [ class "fa fa-bolt" ]
                    []
                ]
            , button
                [ onClick ClearUserSelection ]
                [ span
                    [ class "fa fa-trash" ]
                    []
                ]
            ]
        , selectedNumbersView model.gameMode model.userSelection model.draw
        , if Set.size model.userSelection /= numbersForGameMode model.gameMode then
            numberPadView model

          else
            text ""
        , label
            []
            [ text "Winning numbers" ]
        , div
            [ class "line" ]
            [ drawView model ]
        , div
            [ class "line" ]
            [ label
                []
                [ text "Add Money" ]
            , button
                [ onClick <| Add 10000 ]
                [ text "$100" ]
            , button
                [ onClick <| Add 100000 ]
                [ text "$1,000" ]
            , button
                [ onClick <| Add 1000000 ]
                [ text "$10,000" ]
            ]
        , table
            [ class "table result" ]
            [ tr
                []
                [ th
                    []
                    [ text "Spent" ]
                , td
                    []
                    [ text <| displayDollars model.spent ]
                ]
            , tr
                []
                [ th
                    []
                    [ text "Won" ]
                , td
                    []
                    [ text <| displayDollars model.won ]
                ]
            , tr
                []
                [ th
                    []
                    [ text "Win/Loss" ]
                , td
                    []
                    [ text <| displayDollars (model.won - model.spent) ]
                ]
            , tr
                []
                [ th
                    []
                    [ text "Balance" ]
                , td
                    []
                    [ text <| displayDollars (model.balance - model.spent + model.won) ]
                ]
            ]
        , div
            [ class "line" ]
            [ label
                []
                [ text "Winning Draws" ]
            , button
                [ class "button button-clear"
                , onClick ToggleWinningDraws
                ]
                [ text <|
                    if model.showWinningDraws then
                        "Hide "

                    else
                        "Show "
                , span
                    [ class <|
                        if model.showWinningDraws then
                            "fa fa-arrow-up"

                        else
                            "fa fa-arrow-down"
                    ]
                    []
                ]
            ]
        , lazy3 winningDrawsView model.game model.showWinningDraws model.winningDraws
        , label
            [ class "line" ]
            [ text "Prizes" ]
        , lazy prizesView model.game
        ]


gameModeOption : GameMode -> ( GameMode, Int ) -> Html Msg
gameModeOption selectedGameMode ( gameMode, cost ) =
    option
        [ value <| gameModeString gameMode
        , selected <| selectedGameMode == gameMode
        ]
        [ text <| gameModeString gameMode ++ " - " ++ displayDollars cost ]


selectedNumbersView : GameMode -> Set Int -> Draw -> Html Msg
selectedNumbersView gameMode userSelection draw =
    div
        [ class "line selected-numbers" ]
        ((Set.toList userSelection |> List.map Just)
            ++ List.repeat (numbersForGameMode gameMode) Nothing
            |> List.take (numbersForGameMode gameMode)
            |> List.map (selectedNumber draw)
        )


selectedNumber : Draw -> Maybe Int -> Html Msg
selectedNumber draw mNumber =
    case mNumber of
        Just number ->
            div
                [ onClick <| ToggleNumber number
                , class "pointer"
                , classList
                    [ ( "is-winning", Set.member number draw.numbers )
                    , ( "is-sup", Set.member number draw.supps )
                    ]
                ]
                [ text <| String.fromInt number ]

        Nothing ->
            div
                []
                [ text "" ]


numberPadView : Model -> Html Msg
numberPadView model =
    div
        [ class "line number-pad" ]
        (List.range 0 4 |> List.map (numberRow model.userSelection))


numberRow : Set Int -> Int -> Html Msg
numberRow userSelection row =
    div
        [ class "number-row" ]
        (List.range (row * 9 + 1) (row * 9 + 9) |> List.map (numberView userSelection))


numberView : Set Int -> Int -> Html Msg
numberView userSelection number =
    div
        [ onClick <| ToggleNumber number
        , class "number"
        , classList [ ( "is-selected", Set.member number userSelection ) ]
        ]
        [ text <| String.fromInt number ]


drawView : Model -> Html Msg
drawView { userSelection, draw } =
    div
        [ class "line draw-numbers" ]
        ((draw.numbers
            |> Set.toList
            |> List.map Just)
            ++ (draw.supps
                |> Set.toList
                |> List.map Just
            )
            ++ List.repeat 8 Nothing
            |> List.take 8
            |> List.map (drawNumber userSelection)
        )


drawNumber : Set Int -> Maybe Int -> Html Msg
drawNumber userSelection mNumber =
    div
        [ classList [ ( "is-drawn", isMNumberMember userSelection mNumber ) ] ]
        [ text (Maybe.map String.fromInt mNumber |> Maybe.withDefault "") ]


isMNumberMember : Set Int -> Maybe Int -> Bool
isMNumberMember set mNumber =
    case mNumber of
        Nothing ->
            False

        Just number ->
            Set.member number set


type alias WinningDraw =
    { userSelection : Set Int
    , draw : Draw
    , gameMode : GameMode
    }


winningDrawsView : Game -> Bool -> List WinningDraw -> Html Msg
winningDrawsView game showWinningDraws winningDraws =
    div
        [ class "line" ]
        [ if showWinningDraws then
            if winningDraws /= [] then
                div
                    []
                    (List.map (winningDrawView game) winningDraws)

            else
                div
                    []
                    [ text "No winning draws yet." ]

          else
            text ""
        ]


winningDrawView : Game -> WinningDraw -> Html Msg
winningDrawView game winningDraw =
    div
        [ class "winning-draw" ]
        [ div
            []
            [ text <| "+ " ++ (prize game winningDraw.gameMode winningDraw.userSelection winningDraw.draw |> displayDollars) ++ " (" ++ gameModeString winningDraw.gameMode ++ ")" ]
        , div
            [ class "selected-numbers" ]
            (winningDraw.userSelection |> Set.toList |> List.map (winningDrawNumber winningDraw.draw))
        ]


winningDrawNumber : Draw -> Int -> Html Msg
winningDrawNumber { numbers, supps } number =
    div
        [ classList
            [ ( "is-winning", Set.member number numbers )
            , ( "is-sup", Set.member number supps )
            ]
        ]
        [ text <| String.fromInt number ]


prizesView : Game -> Html Msg
prizesView game =
    Html.table
        [ class "table" ]
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
            ++ List.map prizeRow (prizes game)
        )


prizeRow : Prize -> Html Msg
prizeRow prize_ =
    tr
        []
        [ td
            []
            [ text <| displayNumbers prize_.winningNumbers ++ displaySupps prize_.suppNumbers ]
        , td
            []
            [ text <| String.fromInt prize_.odds ]
        , td
            []
            [ text <| displayDollars prize_.prize ]
        ]


displayNumbers : Int -> String
displayNumbers number =
    if number > 1 then
        String.fromInt number ++ " Numbers"

    else
        "1 Number"


displaySupps : Int -> String
displaySupps number =
    case number of
        0 ->
            ""

        1 ->
            " + 1 Supp"

        i ->
            " + " ++ String.fromInt i ++ " Supps"


gameModeString : GameMode -> String
gameModeString gameMode =
    case gameMode of
        Standard ->
            "Standard"

        Pick int ->
            "Pick " ++ String.fromInt int

        System int ->
            "System " ++ String.fromInt int


type alias Prize =
    { winningNumbers : Int
    , suppNumbers : Int
    , odds : Int
    , prize : Int
    }


prizes : Game -> List Prize
prizes game =
    case game of
        OzLotto ->
            [ Prize 6 0 8145060 1
            , Prize 5 1 678755 1
            , Prize 5 0 36689 1
            , Prize 4 0 733 1
            , Prize 3 1 297 1
            , Prize 1 2 144 1
            ]

        GoldLottoSat ->
            [ Prize 6 0 8145060 59497080
            , Prize 5 1 678755 1177945
            , Prize 5 0 36689 134820
            , Prize 4 0 733 3970
            , Prize 3 1 297 2620
            , Prize 1 2 144 1395
            ]

        GoldLottoMonWed ->
            [ Prize 6 0 8145060 1
            , Prize 5 1 678755 1
            , Prize 5 0 36689 1
            , Prize 4 0 733 1
            , Prize 3 1 297 1
            , Prize 1 2 144 1
            ]


prize : Game -> GameMode -> Set Int -> Draw -> Int
prize game gameMode userSelection { numbers, supps } =
    let
        winningMatches =
            Set.intersect userSelection numbers
                |> Set.size
                |> (\size ->
                        if gameMode == Pick 4 then
                            size + 2

                        else if gameMode == Pick 5 then
                            size + 1

                        else
                            size
                   )

        suppMatches =
            Set.intersect userSelection supps
                |> Set.size
    in
    highestMatchingPrice (prizes game) winningMatches suppMatches


highestMatchingPrice : List Prize -> Int -> Int -> Int
highestMatchingPrice prizes_ winningMatches suppMatches =
    case prizes_ of
        [] ->
            0

        prize_ :: rest ->
            if winningMatches >= prize_.winningNumbers && suppMatches >= prize_.suppNumbers then
                prize_.prize

            else
                highestMatchingPrice rest winningMatches suppMatches


gameEntryCosts : Game -> List ( GameMode, Int )
gameEntryCosts game =
    case game of
        GoldLottoSat ->
            [ ( Standard, 72 )
            , ( Pick 4, 58790 )
            , ( Pick 5, 1870 )
            , ( System 7, 500 )
            , ( System 8, 2010 )
            , ( System 9, 6020 )
            , ( System 10, 15055 )
            , ( System 11, 33125 )
            , ( System 12, 66245 )
            , ( System 13, 123030 )
            , ( System 14, 215300 )
            , ( System 15, 358835 )
            , ( System 16, 574135 )
            , ( System 17, 887295 )
            , ( System 18, 1330945 )
            , ( System 19, 1945230 )
            , ( System 20, 2778900 )
            ]

        GoldLottoMonWed ->
            [ ( Standard, 61 )
            , ( System 7, 425 )
            , ( System 8, 1700 )
            , ( System 9, 5095 )
            , ( System 10, 12740 )
            , ( System 11, 28025 )
            , ( System 12, 56055 )
            , ( System 13, 104100 )
            , ( System 14, 182175 )
            , ( System 15, 303620 )
            , ( System 16, 485805 )
            , ( System 17, 750790 )
            , ( System 18, 1126185 )
            , ( System 19, 1645965 )
            , ( System 20, 2351375 )
            , ( Pick 4, 49745 )
            , ( Pick 5, 2425 )
            ]

        OzLotto ->
            [ ( Standard, 61 )
            , ( System 7, 425 )
            , ( System 8, 1700 )
            , ( System 9, 5095 )
            , ( System 10, 12740 )
            , ( System 11, 28025 )
            , ( System 12, 56055 )
            , ( System 13, 104100 )
            , ( System 14, 182175 )
            , ( System 15, 303620 )
            , ( System 16, 485805 )
            , ( System 17, 750790 )
            , ( System 18, 1126185 )
            , ( System 19, 1645965 )
            , ( System 20, 2351375 )
            , ( Pick 4, 49745 )
            , ( Pick 5, 2425 )
            ]


gameModeEntryCost : Game -> GameMode -> Int
gameModeEntryCost game gameMode =
    gameModeEntryCostHelp (gameEntryCosts game) gameMode


gameModeEntryCostHelp : List ( GameMode, Int ) -> GameMode -> Int
gameModeEntryCostHelp gameEntryCosts_ gameMode =
    case gameEntryCosts_ of
        [] ->
            0

        ( gameMode_, cost ) :: rest ->
            if gameMode_ == gameMode then
                cost

            else
                gameModeEntryCostHelp rest gameMode


stringToGameMode : String -> GameMode
stringToGameMode string =
    case string of
        "System 7" ->
            System 7

        "System 8" ->
            System 8

        "System 9" ->
            System 9

        "System 10" ->
            System 10

        "System 11" ->
            System 11

        "System 12" ->
            System 12

        "System 13" ->
            System 13

        "System 14" ->
            System 14

        "System 15" ->
            System 15

        "System 16" ->
            System 16

        "System 17" ->
            System 17

        "System 18" ->
            System 18

        "System 19" ->
            System 19

        "System 20" ->
            System 20

        "Pick 4" ->
            Pick 4

        "Pick 5" ->
            Pick 5

        _ ->
            Standard


numbersForGameMode : GameMode -> Int
numbersForGameMode gameMode =
    case gameMode of
        Standard ->
            6

        Pick int ->
            int

        System int ->
            int


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



-- HELPERS


toggleSet : comparable -> Set comparable -> Set comparable
toggleSet item set =
    if Set.member item set then
        Set.remove item set

    else
        Set.insert item set
