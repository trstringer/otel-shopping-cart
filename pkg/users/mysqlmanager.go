package users

import (
	"context"
	"database/sql"
	"fmt"

	// Blank import MySQL driver.
	_ "github.com/go-sql-driver/mysql"
	"go.opentelemetry.io/otel"
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
func (m *MySQLManager) GetUser(ctx context.Context, userName string) (*User, error) {
	_, span := otel.Tracer("users").Start(ctx, "DB get user")
	defer span.End()

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
FROM application_user
WHERE
	login = ?;`

	row := db.QueryRow(query, userName)
	var id int
	var login, firstName, lastName string
	err = row.Scan(&id, &login, &firstName, &lastName)
	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("user not found: %s", userName)
	} else if err != nil {
		return nil, fmt.Errorf("error querying user data: %w", err)
	}

	return &User{
		ID:        id,
		Login:     login,
		FirstName: firstName,
		LastName:  lastName,
	}, nil
}
