import ankiconnect
import gleam/dict
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/httpc
import gleam/int
import gleam/list

pub fn main() {
  let configuration = ankiconnect.default_configuration()
  let deck = "test-deck-plz-ignore"

  let _ =
    configuration
    |> ankiconnect.add_note_request(
      ankiconnect.NewNote(
        deck_name: deck,
        model_name: "Basic (and reversed card)",
        fields: dict.from_list([
          #("Front", int.random(10_000) |> int.to_string),
          #("Back", int.random(10_000) |> int.to_string),
        ]),
        tags: ["tag1", "tag2"],
        audio: [],
        video: [],
        picture: [
          ankiconnect.NewNoteMediaFile(
            filename: "wibble",
            source: ankiconnect.Path("/Users/louis/Desktop/blah.png"),
            fields: ["Front"],
          ),
        ],
      ),
    )
    |> assert_send
    |> ankiconnect.add_note_response
    |> echo

  let assert Ok(notes) =
    configuration
    |> ankiconnect.notes_info_query_request("deck:" <> deck)
    |> assert_send
    |> ankiconnect.notes_info_response

  echo list.length(notes) as "num notes in deck"
  echo notes
}

fn assert_send(request: Request(String)) -> Response(String) {
  let assert Ok(response) = httpc.send(request)
  response
}
