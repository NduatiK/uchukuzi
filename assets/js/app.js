//
// Import dependencies
//
import "phoenix_html"

// Import local files
//
// Local files can be imported directly using relative paths, for example:
// import socket from "./socket"
import { Elm } from '../src/Main.elm'

Elm.Main.init({
    // flags: [],
    node: document.getElementById("elm")
})