import ankiconnect
import gleam/dict
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/httpc
import gleam/int
import gleam/list

pub fn main() {
  // let deck = "Irish::lpil::CityLit Irish::Beginners module 2"
  let deck = "test-deck-plz-ignore"

  let assert Ok(all_notes) =
    ankiconnect.notes_info_query_request("deck:\"" <> deck <> "\" -[sound:")
    |> assert_send
    |> ankiconnect.notes_info_response

  list.each(all_notes, fn(note) { echo note })
}

fn assert_send(request: Request(String)) -> Response(String) {
  let assert Ok(response) = httpc.send(request)
  response
}
