package authz

allow[result] {
	some user
    data.users[user].id == input.id
    result := data.users[user]
}
