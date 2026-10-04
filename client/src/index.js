/// Login functions

// attempts to login the current user if username
// is null itll attempt to use a cached login password
// is a set of 4 characters representing the chosen symbols.
// returns the username of the logged in player, or null
// on failure to login
export function try_login(username, password) {
  if (username == null || username.length == 0) return null;

  console.log("TODO: login " + username);

  return username;
}

/// Match joining functions

// gets the current players match making score
// and rank
export function get_score() {
  console.log("TODO: get mmr score");

  return 0;
}

// try and join a match, should be proceeded by
// poll_match eventually returning true
export function join_match() {
  console.log("TODO: send match join");
}

// cancel joining, poll match will not be
// called after this
export function cancel_match() {
  console.log("TODO: send match cancel");
}

// player confirmation, should be proceeded by
// poll_ready eventually returning true
export function ready_match() {
  console.log("TODO: send match begin");
}

// This is called while waiting for a match
// If a match has been found it returns true
export function poll_match() {
  console.log("TODO: poll match");

  return false;
}

// This is called while waiting for the opponent
// to confirm, if they have confirmed it returns
// true
export function poll_ready() {
  console.log("TODO: poll ready");

  return false;
}

/// Gameplay functions
// This is called by the game when a shop purchase
// is made it transmits things in a string value
export function shop_purchase(state) {
  // This should return early if theres no running client
  // it can be ran in practice mode.

  console.log("TODO: send shop data");
}

// This is called by the game every once in a
// while, it should return the current shop state
// of the opponent if it returns an empty string
// it means no data has been sent from the opponent
export function shop_sync() {
  console.log("TODO: sync shop data");

  return "";
}
