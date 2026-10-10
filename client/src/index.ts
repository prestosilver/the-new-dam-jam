import {io} from "socket.io-client";

const socket = io("https://games.samichamberlain.com", {
  path : "/darts-2-million/",
  transports : [ "websocket" ],
});

/// functions defined in main.zig (search function)
declare function set_score(name: number): void;
declare function set_username(name: string): void;
declare function set_opponent(name: string): void;
declare function set_leaderboard(list_index: number, name: string,
                                 mmr: number): void;
declare function unset_leaderboard(list_index: number): void;

/// Global state
// matchmaking
let match_found: boolean = false;
let match_ready: boolean = false;

// shop
let opponent_shop_data: string = "";

/// Login functions

// attempts to login the current user if username
// is null itll attempt to use a cached login password
// is a set of 4 characters representing the chosen symbols.
// returns the username of the logged in player, or null
// on failure to login
export function try_login(
    username: string|null,
    password: string|null,
    ): boolean {

  if (username == null || username.length == 0) {
    username = localStorage.getItem("d2m_username");
    password = localStorage.getItem("d2m_password");
  }

  if (username == null || password == null) 
      return false;

  set_username("");
  socket.emit("login", {username, password}, (response: boolean) => {
    set_username(username!);

    const date = new Date();
    // Convert days to milliseconds
    date.setTime(date.getTime() + (100 * 24 * 60 * 60 * 1000));
    localStorage.setItem("d2m_username", username);
    localStorage.setItem("d2m_password", password);
  });

  return true;
}

/// Match joining functions

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
export function ready_match() { socket.emit("match:ready"); }

// This is called while waiting for a match
// If a match has been found it returns true
export function poll_match() { return match_found; }

// This is called while waiting for the opponent
// to confirm, if they have confirmed it returns
// true
export function poll_ready() { return match_ready; }

/// Gameplay functions
// This is called by the game when a shop purchase
// is made it transmits things in a string value
export function shop_purchase(state: string) {
  if (!match_ready)
    return;

  socket.emit("shop:send", state);
}

// This is called by the game every once in a
// while, it should return the current shop state
// of the opponent if it returns an empty string
// it means no data has been sent from the opponent
export function shop_sync() { return opponent_shop_data; }

let leaderboard_start: number = 0;
let leaderboard_count: number = 0;

// Requests leaderboard page
export function leaderboard_page(start: number, count: number) {
  leaderboard_start = start;
  leaderboard_count = count;
  for (let i = 0; i < count; i++)
    unset_leaderboard(i);
  socket.emit("leaderboard:request", {start, count});

  // for (let i = 0; i < count; i++) {
  //   function getRandomTime(min: number, max: number): number {
  //     return Math.floor(Math.random() * (max - min + 1)) + min;
  //   }
  //
  //   const delay = getRandomTime(0, 300);
  //   const mmr = (i + start) * 1000;
  //   const index = start + i;

  //   if (index < 37)
  //     setTimeout(() => {
  //       if (index >= leaderboard_start && index < leaderboard_start +
  //       leaderboard_count)
  //         set_leaderboard(index - leaderboard_start, "test", mmr);
  //     }, delay);
  // }
}

// Socket Listeners -- server responses are in args

// Matchmaking
socket.on("match:found", () => { match_found = true; });

socket.on("match:start", () => { match_ready = true; });

socket.on("opponent:get", (name: string) => { set_opponent(name); });

// Score
socket.on("score:get", (score: number) => { set_score(score); });

// opponent shop
socket.on("shop:sync", (state: string) => { opponent_shop_data = state; });

// opponent shop
socket.on("leaderboard:value", (index: number, name: string, mmr: number) => {
  // if user is paging fast this will
  if (index >= leaderboard_start &&
      index < leaderboard_start + leaderboard_count)
    set_leaderboard(index - leaderboard_start, name, mmr);
});
