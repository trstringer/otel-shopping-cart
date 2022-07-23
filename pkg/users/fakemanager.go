package users

// FakeUserManager is the fake representation for a user manager.
type FakeUserManager struct{}

// GetUser returns a fake user.
func (f FakeUserManager) GetUser(userName string) (*User, error) {
	return &User{
		ID:        1,
		Login:     userName,
		FirstName: "first1",
		LastName:  "last1",
	}, nil
}
