import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"

let csrfToken =
  document
    .querySelector("meta[name='csrf-token']")
    .getAttribute("content")

let Hooks = {}

Hooks.ScrollBottom = {
  mounted() {
    this.scrollToBottom()
  },
  updated (){
    this.scrollToBottom()
  },
  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeigth
  }
}

let liveSocket =
  new LiveSocket("/live", Socket, {
    params: {
      _csrf_token: csrfToken
    }
  })

liveSocket.connect()

window.liveSocket = liveSocket