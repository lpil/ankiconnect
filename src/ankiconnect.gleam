import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/json.{type Json}

pub type Configuration {
  Configuration(host: String, port: Int)
}

pub type ActionError {
  AnkiActionFailed(String)
  FailedToDecodeResponse(json.DecodeError)
}

pub type FieldData {
  FieldData(value: String, order: Int)
}

pub type NoteInfo {
  NoteInfo(
    note_id: Int,
    model_name: String,
    tags: List(String),
    fields: Dict(String, FieldData),
  )
}

pub fn default_configuration() -> Configuration {
  Configuration(host: "localhost", port: 8765)
}

fn make_request(
  config: Configuration,
  action: String,
  parameters: List(#(String, Json)),
) -> Request(String) {
  let payload =
    json.object([
      #("version", json.int(6)),
      #("action", json.string(action)),
      #("params", json.object(parameters)),
    ])

  request.new()
  |> request.set_scheme(http.Http)
  |> request.set_method(http.Post)
  |> request.set_host(config.host)
  |> request.set_port(config.port)
  |> request.set_body(json.to_string(payload))
  |> request.prepend_header("content-type", "application/json")
}

fn handle_response(
  response: Response(String),
  decoder: decode.Decoder(t),
) -> Result(t, ActionError) {
  let success = decode.at(["result"], decoder) |> decode.map(Ok)
  let failure = decode.at(["error"], decode.string) |> decode.map(Error)
  let decoder = decode.one_of(success, [failure])
  case json.parse(response.body, decoder) {
    Ok(Ok(value)) -> Ok(value)
    Ok(Error(error)) -> Error(AnkiActionFailed(error))
    Error(error) -> Error(FailedToDecodeResponse(error))
  }
}

/// Gets the complete list of deck names for the current user. 
pub fn deck_names_request(config: Configuration) -> Request(String) {
  make_request(config, "deckNames", [])
}

/// Parse the response for the deck names request.
pub fn deck_names_response(
  response: Response(String),
) -> Result(List(String), ActionError) {
  handle_response(response, decode.list(decode.string))
}

/// Returns the matching card IDs for a query.
pub fn find_cards_request(
  config: Configuration,
  query: String,
) -> Request(String) {
  make_request(config, "findCards", [#("query", json.string(query))])
}

/// Parses the response for a findCards request.
pub fn find_cards_response(
  response: Response(String),
) -> Result(List(Int), ActionError) {
  handle_response(response, decode.list(decode.int))
}

/// Gets the complete list of deck names and their respective IDs for the current user.
pub fn deck_names_and_ids_request(config: Configuration) -> Request(String) {
  make_request(config, "deckNamesAndIds", [])
}

/// Parses the response for a deckNamesAndIds request.
pub fn deck_names_and_ids_response(
  response: Response(String),
) -> Result(Dict(String, Int), ActionError) {
  handle_response(response, decode.dict(decode.string, decode.int))
}

/// Returns an array of note IDs for a given query.
pub fn find_notes_request(
  config: Configuration,
  query: String,
) -> Request(String) {
  make_request(config, "findNotes", [#("query", json.string(query))])
}

/// Parses the response for a findNotes request.
pub fn find_notes_response(
  response: Response(String),
) -> Result(List(Int), ActionError) {
  handle_response(response, decode.list(decode.int))
}

fn note_info_decoder() -> decode.Decoder(NoteInfo) {
  use note_id <- decode.field("noteId", decode.int)
  use model_name <- decode.field("modelName", decode.string)
  use tags <- decode.field("tags", decode.list(decode.string))
  use fields <- decode.field(
    "fields",
    decode.dict(decode.string, field_data_decoder()),
  )
  decode.success(NoteInfo(note_id:, model_name:, tags:, fields:))
}

fn field_data_decoder() -> decode.Decoder(FieldData) {
  use value <- decode.field("value", decode.string)
  use order <- decode.field("order", decode.int)
  decode.success(FieldData(value:, order:))
}

/// Gets the note info for a list of note IDs.
pub fn notes_info_request(
  config: Configuration,
  ids: List(Int),
) -> Request(String) {
  make_request(config, "notesInfo", [#("notes", json.array(ids, json.int))])
}

/// Parses the response for a notesInfo request.
pub fn notes_info_response(
  response: Response(String),
) -> Result(List(NoteInfo), ActionError) {
  handle_response(response, decode.list(note_info_decoder()))
}

/// Gets the note info for a query.
///
/// Use with `notes_info_response`.
pub fn notes_info_query_request(
  config: Configuration,
  query: String,
) -> Request(String) {
  make_request(config, "notesInfo", [#("query", json.string(query))])
}

pub type MediaFileUpload {
  MediaFileUpload(
    filename: String,
    source: MediaFileSource,
    delete_existing: Bool,
  )
}

/// The source for a media file that can be added to an Anki deck.
pub type MediaFileSource {
  Base64Data(String)
  Path(String)
  Url(String)
}

/// Stores a file with the specified base64-encoded contents inside the media folder.
///
/// Alternatively you can specify a absolute file path, or a url from where the
/// file shell be downloaded.
///
/// To prevent Anki from removing files not used by any cards (e.g. for
/// configuration files), prefix the filename with an underscore. These files
/// are still synchronized to AnkiWeb.
///
/// Any existing file with the same name is deleted by default.
///
/// Set deleteExisting to false to prevent that by letting Anki give the new
/// file a non-conflicting name.
///
pub fn store_media_file_request(
  config: Configuration,
  media_file: MediaFileUpload,
) -> Request(String) {
  let MediaFileUpload(filename:, source:, delete_existing:) = media_file

  let source_param = case source {
    Base64Data(data) -> #("data", json.string(data))
    Path(path) -> #("path", json.string(path))
    Url(url) -> #("url", json.string(url))
  }

  make_request(config, "storeMediaFile", [
    #("filename", json.string(filename)),
    #("deleteExisting", json.bool(delete_existing)),
    source_param,
  ])
}

/// Parses the response for a storeMediaFile request.
pub fn store_media_file_response(
  response: Response(String),
) -> Result(String, ActionError) {
  handle_response(response, decode.string)
}
