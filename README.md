# ankiconnect

A Gleam client for [Anki Connect](https://ankiweb.net/shared/info/2055492159)
and [Anki Connect Plus](https://ankiweb.net/shared/info/2036732292).

[![Package Version](https://img.shields.io/hexpm/v/ankiconnect)](https://hex.pm/packages/ankiconnect)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/ankiconnect/)

```sh
gleam add ankiconnect@1
```
```gleam
import ankiconnect
import gleam/httpc

pub fn run() {
  let assert Ok(response) = ankiconnect.deck_names_request() |> httpc.send
  let assert Ok(decks) = ankiconnect.deck_names_response(response)
  echo decks
}
```

Further documentation can be found at <https://hexdocs.pm/ankiconnect>.
