import ankiconnect
import gleam/httpc
import gleam/list

pub fn main() {
  let configuration = ankiconnect.default_configuration()
  let assert Ok(response) =
    configuration
    |> ankiconnect.notes_info_query_request("deck:current -[sound")
    |> httpc.send

  let assert Ok(notes) = ankiconnect.notes_info_response(response)

  echo list.length(notes)
  // list.each(notes, fn(note) { echo note })
}
