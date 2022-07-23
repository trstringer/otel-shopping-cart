package users

import (
	"database/sql"
	"fmt"

	// Blank import MySQL driver.
	_ "github.com/go-sql-driver/mysql"
)

// MySQLManager implements the Manager interface using MySQL as the
// persistent datastore.
type MySQLManager struct {
	address  string
	database string
	user     string
	password string
}

// NewMySQLManager get a new MySQL manager for interacting with the
// database.
func NewMySQLManager(address, database, user, password string) *MySQLManager {
	return &MySQLManager{
		address:  address,
		database: database,
		user:     user,
		password: password,
	}
}

func (m MySQLManager) dataSourceName() string {
	return fmt.Sprintf(
		"%s:%s@tcp(%s)/%s",
		m.user,
		m.password,
		m.address,
		m.database,
	)
}

// GetUser returns a user from the database.
func (m *MySQLManager) GetUser(userName string) (*User, error) {
	db, err := sql.Open("mysql", m.dataSourceName())
	if err != nil {
		return nil, fmt.Errorf("error opening database connection: %w", err)
	}
	defer db.Close()

	query := `
SELECT
	id,
	login,
	first_name,
	last_name
FROM application_user;`

	d:wq:w::wqa
	:wqa

	return nil, nil
}
