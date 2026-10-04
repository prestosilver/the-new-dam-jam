/// Login functions

// attempts to login the current user if username
// is null itll attempt to use a cached login password
// is a set of 4 characters representing the chosen symbols.
// returns the username of the logged in player, or null
// on failure to login
function try_login(username, password) {
    console.log("TODO: login");

    return null;
}

/// Match joining functions

// gets the current players match making score
// and rank
function get_score() {
    console.log("TODO: get mmr score");

    return 0;
}

// try and join a match, should be proceeded by
// poll_match eventually returning true
function join_match() {
    console.log("TODO: send match join");
}

// cancel joining, poll match will not be 
// called after this
function cancel_match() {
    console.log("TODO: send match cancel");
}

// player confirmation, should be proceeded by
// poll_ready eventually returning true
function ready_match() {
    console.log("TODO: send match begin");
}

// This is called while waiting for a match
// If a match has been found it returns true
function poll_match() {
    console.log("TODO: poll match");
    
    return false;
}

// This is called while waiting for the opponent
// to confirm, if they have confirmed it returns
// true
function poll_ready() {
    console.log("TODO: poll ready");

    return false;
}

/// Gameplay functions
// This is called by the game when a shop purchase
// is made it transmits things in a string value
function shop_purchase(state) {
    // This should return early if theres no running client
    // it can be ran in practice mode.
    
    console.log("TODO: send shop data");
}

// This is called by the game every once in a
// while, it should return the current shop state
// of the opponent if it returns an empty string
// it means no data has been sent from the opponent
function shop_sync() {
    console.log("TODO: sync shop data");

    return "";
}
