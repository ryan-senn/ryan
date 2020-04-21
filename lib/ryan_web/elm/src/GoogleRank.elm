module GoogleRank exposing (main)

import Browser
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Url exposing (Url)


type alias Flags =
    { apiEndpoint : String
    , csrfToken : String
    }


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = always Sub.none
        }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( { flags = flags
      , domain = "tt.edu.au"
      , keywords = "White Card Gold Coast"
      , searchResults = Dict.empty
      , isSearching = False
      , error = ""
      }
    , Cmd.none
    )


type alias Backlink =
    { href : String
    , isFollow : Bool
    }


type alias SearchResult =
    { position : Int
    , url : Maybe Url
    , backlinks : Maybe (List Backlink)
    }


type alias Model =
    { flags : Flags
    , domain : String
    , keywords : String
    , searchResults : Dict String SearchResult
    , isSearching : Bool
    , error : String
    }


type Msg
    = UpdateDomain String
    | UpdateKeywords String
    | SearchRequest
    | SearchResponse (Result Http.Error (List String))
    | BacklinksResponse String (Result Http.Error (List Backlink))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UpdateDomain domain ->
            ( { model | domain = domain }, Cmd.none )

        UpdateKeywords keywords ->
            ( { model | keywords = keywords }, Cmd.none )

        SearchRequest ->
            ( { model | isSearching = True }, searchRequest model.flags model.keywords )

        SearchResponse (Err _) ->
            ( { model | error = "Search Http Error", isSearching = False }, Cmd.none )

        SearchResponse (Ok searchResults) ->
            ( { model
                | searchResults = initSearchResults searchResults
                , isSearching = False
              }
            , initBacklinksRequests model.flags model.domain searchResults
            )

        BacklinksResponse url (Err _) ->
            ( { model
                | error = "Backlinks Http Error for " ++ url
                , searchResults = mergeBacklinks url [] model.searchResults
              }
            , Cmd.none
            )

        BacklinksResponse url (Ok backlinks) ->
            ( { model | searchResults = mergeBacklinks url backlinks model.searchResults }, Cmd.none )


mergeBacklinks : String -> List Backlink -> Dict String SearchResult -> Dict String SearchResult
mergeBacklinks url backlinks searchResults =
    Dict.update url (mergeBacklinksHelp backlinks) searchResults


mergeBacklinksHelp : List Backlink -> Maybe SearchResult -> Maybe SearchResult
mergeBacklinksHelp backlinks mSearchResult =
    Maybe.map (\searchResult -> { searchResult | backlinks = Just backlinks }) mSearchResult


searchRequest : Flags -> String -> Cmd Msg
searchRequest flags keywords =
    Http.post
        { url = flags.apiEndpoint ++ "/search"
        , body =
            Http.jsonBody <|
                Encode.object
                    [ ( "keywords", Encode.string keywords )
                    , ( "_csrf_token", Encode.string flags.csrfToken )
                    ]
        , expect = Http.expectJson SearchResponse (Decode.list Decode.string)
        }


initSearchResults : List String -> Dict String SearchResult
initSearchResults searchResults =
    searchResults
        |> List.indexedMap (\position searchResult -> ( searchResult, SearchResult position (Url.fromString searchResult) Nothing ))
        |> Dict.fromList


initBacklinksRequests : Flags -> String -> List String -> Cmd Msg
initBacklinksRequests flags domain searchResults =
    searchResults
        |> List.map (backlinksRequest flags domain)
        |> Cmd.batch


backlinksRequest : Flags -> String -> String -> Cmd Msg
backlinksRequest flags domain searchResult =
    Http.post
        { url = flags.apiEndpoint ++ "/backlinks"
        , body =
            Http.jsonBody <|
                Encode.object
                    [ ( "url", Encode.string searchResult )
                    , ( "domain", Encode.string domain )
                    , ( "_csrf_token", Encode.string flags.csrfToken )
                    ]
        , expect = Http.expectJson (BacklinksResponse searchResult) (Decode.list backlinkDecoder)
        }


backlinkDecoder : Decoder Backlink
backlinkDecoder =
    Decode.map2 Backlink
        (Decode.field "href" Decode.string)
        (Decode.field "isFollow" Decode.bool)


view : Model -> Html Msg
view model =
    div
        []
        [ Html.form
            [ onSubmit SearchRequest ]
            [ div
                [ class "form-group" ]
                [ label
                    [ for "domain" ]
                    [ text "Domain" ]
                , input
                    [ class "form-control", id "domain", value model.domain, onInput UpdateDomain ]
                    []
                ]
            , div
                [ class "form-group" ]
                [ label
                    [ for "keywords" ]
                    [ text "Keywords" ]
                , input
                    [ class "form-control", id "keywords", value model.keywords, onInput UpdateKeywords ]
                    []
                ]
            , input
                [ type_ "submit", class "form-control" ]
                [ text "Submit" ]
            ]
        , div
            []
            [ if model.isSearching then
                text "Loading ..."

              else if Dict.isEmpty model.searchResults then
                text ""

              else
                table
                    [ class "table table-striped" ]
                    [ tr
                        []
                        [ th
                            [ class "rank" ]
                            [ text "#" ]
                        , th
                            [ class "url" ]
                            [ text "URL" ]
                        ]
                    , tbody
                        []
                        (Dict.toList model.searchResults |> List.sortBy (\( _, searchResult ) -> searchResult.position) |> List.map (searchResultRow model.domain))
                    ]
            ]
        ]


searchResultRow : String -> ( String, SearchResult ) -> Html Msg
searchResultRow domain ( url, searchResult ) =
    let
        isActive_ =
            isActive domain searchResult.url
    in
    tr
        [ classList [ ( "active", isActive_ ) ] ]
        [ td
            []
            [ text <| String.fromInt <| searchResult.position + 1 ]
        , td
            [ class "url", classList [ ( "loading", searchResult.backlinks == Nothing ) ] ]
            [ div
                []
                [ text url ]
            , case ( isActive_, searchResult.backlinks ) of
                ( True, _ ) ->
                    text ""

                ( False, Nothing ) ->
                    div
                        [ class "spinner-grow" ]
                        []

                ( False, Just backlinks ) ->
                    div
                        [ class "backlinks" ]
                        (List.map backlink backlinks)
            ]
        ]


backlink : Backlink -> Html Msg
backlink backlink_ =
    div
        []
        [ span
            [ class "fas fa-level-up-alt" ]
            []
        , text backlink_.href
        ]


isActive : String -> Maybe Url -> Bool
isActive domain mUrl =
    Just domain == Maybe.map .host mUrl || Just ("www." ++ domain) == Maybe.map .host mUrl
