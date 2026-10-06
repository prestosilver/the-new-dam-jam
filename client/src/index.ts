import { io } from "socket.io-client";

const socket = io("https://games.samichamberlain.com", {
  path: "/darts-2-million/",
  transports: ["websocket"],
});

//Global state
//Login
let login_done: boolean = false;
let login_valid: boolean = false;
let login_name: string = "";
//score
let score: number = -1;

//opponent info
let opponent_name: string = "";

//matchmaking
let match_found: boolean = false;
let match_ready: boolean = false;

//shop
let opponent_shop_data: string = "";

/// Login functions

// attempts to login the current user if username
// is null itll attempt to use a cached login password
// is a set of 4 characters representing the chosen symbols.
// returns the username of the logged in player, or null
// on failure to login
export function try_login(
  username: string | null,
  password: string | null,
): void {
  if (username == null || username.length == 0)
      return;

  login_done = false;
  socket.emit("login", { username, password }, (response: boolean) => {
    login_done = true;
    login_name = username;
    login_valid = response;
  });
}

export function poll_login(): string {
  if (login_done) {
    login_done = false;
    return login_name;
  }

  return "";
}

export function get_opponent_info() {
  return opponent_name;
}

/// Match joining functions

// gets the current players match making score
// and rank
export function get_score() {
  return score;
}

// try and join a match, should be proceeded by
// poll_match eventually returning true
export function join_match() {
  match_found = false;
  match_ready = false;
  socket.emit("queue:join");
}

// cancel joining, poll match will not be
// called after this
export function cancel_match() {
  match_found = false;
  match_ready = false;
  socket.emit("match:cancel");
}

// player confirmation, should be proceeded by
// poll_ready eventually returning true
export function ready_match() {
  socket.emit("match:ready");
}

// This is called while waiting for a match
// If a match has been found it returns true
export function poll_match() {
  return match_found;
}

// This is called while waiting for the opponent
// to confirm, if they have confirmed it returns
// true
export function poll_ready() {
  return match_ready;
}

/// Gameplay functions
// This is called by the game when a shop purchase
// is made it transmits things in a string value
export function shop_purchase(state: string) {
  if (!match_ready) return;

  socket.emit("shop:send", state);
}

// This is called by the game every once in a
// while, it should return the current shop state
// of the opponent if it returns an empty string
// it means no data has been sent from the opponent
export function shop_sync() {
  return opponent_shop_data;
}

// Socket Listeners -- server responses are in args

//Matchmaking
socket.on("match:found", () => {
  match_found = true;
});

socket.on("match:start", () => {
  match_ready = true;
});

socket.on("opponent:get", (name: string) => {
  opponent_name = name;
});

//Score
socket.on("score:get", (s: number) => {
  score = s;
});

//opponent shop
socket.on("shop:sync", (state: string) => {
  opponent_shop_data = state;
});
