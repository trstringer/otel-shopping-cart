package users

import (
	"context"
	"database/sql"
	"fmt"

	_ "github.com/lib/pq"
	"github.com/trstringer/otel-shopping-cart/pkg/telemetry"
	"go.opentelemetry.io/otel"
)

// DBManager implements the Manager interface using PostgreSQL as the
// persistent datastore.
type DBManager struct {
	address  string
	database string
	user     string
	password string
}

// NewDBManager get a new PostgreSQL manager for interacting with the
// database.
func NewDBManager(address, database, user, password string) *DBManager {
	return &DBManager{
		address:  address,
		database: database,
		user:     user,
		password: password,
	}
}

func (m DBManager) dataSourceName() string {
	return fmt.Sprintf(
		"postgresql://%s:%s@%s/%s?sslmode=disable",
		m.user,
		m.password,
		m.address,
		m.database,
	)
}

// GetUser returns a user from the database.
func (m *DBManager) GetUser(ctx context.Context, userName string) (*User, error) {
	_, span := otel.Tracer(telemetry.TelemetryLibrary).Start(ctx, "db_get_user")
	defer span.End()

	db, err := sql.Open("postgres", m.dataSourceName())
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
	login = $1;`

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

func (m *DBManager) GetAllUsers() ([]*User, error) {
	db, err := sql.Open("postgres", m.dataSourceName())
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

	rows, err := db.Query(query)
	if err != nil {
		return nil, fmt.Errorf("error getting all users: %w", err)
	}
	defer rows.Close()

	users := []*User{}
	for rows.Next() {
		var id int
		var login, firstName, lastName string
		err = rows.Scan(&id, &login, &firstName, &lastName)
		if err != nil {
			return nil, fmt.Errorf("error scanning row: %w", err)
		}
		users = append(users, &User{
			ID:        id,
			Login:     login,
			FirstName: firstName,
			LastName:  lastName,
		})
	}

	return users, nil
}
