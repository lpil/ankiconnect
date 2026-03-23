import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/json.{type Json}
import gleam/list

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

fn make_request(
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
  |> request.set_host("localhost")
  |> request.set_port(8765)
  |> request.set_body(json.to_string(payload))
  |> request.prepend_header("content-type", "application/json")
}

fn handle_response(
  response: Response(String),
  decoder: decode.Decoder(t),
) -> Result(t, ActionError) {
  let success = decode.at(["result"], decoder) |> decode.map(Ok)
  let failure = decode.at(["error"], decode.string) |> decode.map(Error)
  let decoder = decode.one_of(failure, [success])
  case json.parse(response.body, decoder) {
    Ok(Ok(value)) -> Ok(value)
    Ok(Error(error)) -> Error(AnkiActionFailed(error))
    Error(error) -> Error(FailedToDecodeResponse(error))
  }
}

/// Gets the complete list of deck names for the current user. 
pub fn deck_names_request() -> Request(String) {
  make_request("deckNames", [])
}

/// Parse the response for the deck names request.
pub fn deck_names_response(
  response: Response(String),
) -> Result(List(String), ActionError) {
  handle_response(response, decode.list(decode.string))
}

/// Returns the matching card IDs for a query.
pub fn find_cards_request(query: String) -> Request(String) {
  make_request("findCards", [#("query", json.string(query))])
}

/// Parses the response for a findCards request.
pub fn find_cards_response(
  response: Response(String),
) -> Result(List(Int), ActionError) {
  handle_response(response, decode.list(decode.int))
}

/// Gets the complete list of deck names and their respective IDs for the current user.
pub fn deck_names_and_ids_request() -> Request(String) {
  make_request("deckNamesAndIds", [])
}

/// Parses the response for a deckNamesAndIds request.
pub fn deck_names_and_ids_response(
  response: Response(String),
) -> Result(Dict(String, Int), ActionError) {
  handle_response(response, decode.dict(decode.string, decode.int))
}

/// Returns an array of note IDs for a given query.
pub fn find_notes_request(query: String) -> Request(String) {
  make_request("findNotes", [#("query", json.string(query))])
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
pub fn notes_info_request(ids: List(Int)) -> Request(String) {
  make_request("notesInfo", [#("notes", json.array(ids, json.int))])
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
pub fn notes_info_query_request(query: String) -> Request(String) {
  make_request("notesInfo", [#("query", json.string(query))])
}

/// The source for a media file that can be added to an Anki deck.
pub type MediaFileSource {
  Base64Data(String)
  Path(String)
  Url(String)
}

pub type NoteMediaFile {
  NoteMediaFile(filename: String, source: MediaFileSource, fields: List(String))
}

pub type Note {
  NewNote(
    deck_name: String,
    model_name: String,
    fields: Dict(String, String),
    tags: List(String),
    audio: List(NoteMediaFile),
    video: List(NoteMediaFile),
    picture: List(NoteMediaFile),
  )
}

fn encode_note_media_file(file: NoteMediaFile) -> Json {
  let source_param = media_file_source_parameter(file.source)
  json.object([
    #("filename", json.string(file.filename)),
    #("fields", json.array(file.fields, json.string)),
    source_param,
  ])
}

fn media_file_source_parameter(source: MediaFileSource) -> #(String, Json) {
  case source {
    Base64Data(data) -> #("data", json.string(data))
    Path(path) -> #("path", json.string(path))
    Url(url) -> #("url", json.string(url))
  }
}

fn encode_note(note: Note) -> Json {
  let fields_json =
    dict.to_list(note.fields)
    |> list.map(fn(pair) { #(pair.0, json.string(pair.1)) })
    |> json.object

  json.object([
    #("deckName", json.string(note.deck_name)),
    #("modelName", json.string(note.model_name)),
    #("fields", fields_json),
    #("tags", json.array(note.tags, json.string)),
    #("audio", json.array(note.audio, encode_note_media_file)),
    #("video", json.array(note.video, encode_note_media_file)),
    #("picture", json.array(note.picture, encode_note_media_file)),
  ])
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
  filename: String,
  source: MediaFileSource,
  delete_existing delete_existing: Bool,
) -> Request(String) {
  make_request("storeMediaFile", [
    #("filename", json.string(filename)),
    #("deleteExisting", json.bool(delete_existing)),
    media_file_source_parameter(source),
  ])
}

/// Parses the response for a storeMediaFile request.
pub fn store_media_file_response(
  response: Response(String),
) -> Result(String, ActionError) {
  handle_response(response, decode.string)
}

/// Creates a note using the given deck and model, with the provided field values and tags.
/// Returns the identifier of the created note created on success.
pub fn add_note_request(note: Note) -> Request(String) {
  make_request("addNote", [#("note", encode_note(note))])
}

/// Parses the response for an addNote request.
pub fn add_note_response(response: Response(String)) -> Result(Int, ActionError) {
  handle_response(response, decode.int)
}

/// Modify the fields of an existing note.
pub fn update_note_fields_request(
  id: Int,
  fields: Dict(String, String),
) -> Request(String) {
  let fields_json =
    dict.to_list(fields)
    |> list.map(fn(pair) { #(pair.0, json.string(pair.1)) })
    |> json.object

  make_request("updateNoteFields", [
    #(
      "note",
      json.object([
        #("id", json.int(id)),
        #("fields", fields_json),
      ]),
    ),
  ])
}

/// Parses the response for an updateNoteFields request.
pub fn update_note_fields_response(
  response: Response(String),
) -> Result(Nil, ActionError) {
  handle_response(response, decode.success(Nil))
}
