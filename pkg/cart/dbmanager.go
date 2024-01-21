package cart

import (
	"context"
	"database/sql"
	"fmt"

	_ "github.com/lib/pq"
	"github.com/trstringer/otel-shopping-cart/pkg/telemetry"
	"github.com/trstringer/otel-shopping-cart/pkg/users"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/trace"
)

// DBManager is the PostgreSQL implementation for the cart manager.
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

func (m *DBManager) setUserLastAccess(ctx context.Context, user *users.User) error {
	_, span := otel.Tracer(telemetry.TelemetryLibrary).Start(ctx, "db_set_user_last_access")
	defer span.End()

	db, err := sql.Open("postgres", m.dataSourceName())
	if err != nil {
		return fmt.Errorf("error opening database connection: %w", err)
	}
	defer db.Close()

	query := `
UPDATE application_user
SET last_access = NOW()
WHERE
	login = $1;`

	if _, err = db.Exec(query, user.Login); err != nil {
		return fmt.Errorf("error setting last user access for user %s: %w", user.Login, err)
	}

	return nil
}

// GetUserCart returns the user cart.
func (m *DBManager) GetUserCart(ctx context.Context, user *users.User) (*Cart, error) {
	_, span := otel.Tracer(telemetry.TelemetryLibrary).Start(ctx, "db_get_cart")
	defer span.End()

	db, err := sql.Open("postgres", m.dataSourceName())
	if err != nil {
		return nil, fmt.Errorf("error opening database connection: %w", err)
	}
	defer db.Close()

	query := `
SELECT
    p.id AS product_id,
    p.name AS name,
	c.quantity
FROM application_user au
INNER JOIN cart c
ON au.id = c.application_user_id
INNER JOIN product p
ON c.product_id = p.id
WHERE
    au.login = $1;`

	rows, err := db.Query(query, user.Login)
	if err != nil {
		return nil, fmt.Errorf("error querying cart: %w", err)
	}
	userCart := NewCart(user)

	rowCount := 0
	for rows.Next() {
		var id, quantity int
		var productName string
		err = rows.Scan(&id, &productName, &quantity)
		if err != nil {
			break
		}
		rowCount++
		userCart.Products = append(
			userCart.Products,
			Product{ID: id, Name: productName, Quantity: quantity},
		)
	}
	span.AddEvent(
		"Successfully retrieved rows from database",
		trace.WithAttributes(attribute.Int("row.count", rowCount)),
	)

	if errClose := rows.Close(); errClose != nil {
		return nil, fmt.Errorf("error closing rows: %w", err)
	}

	if err != nil {
		return nil, fmt.Errorf("error reading rows: %w", err)
	}

	if err := m.setUserLastAccess(ctx, user); err != nil {
		return nil, fmt.Errorf("error setting last user access: %w", err)
	}

	return userCart, nil
}

// AddItem adds an item to a user cart.
func (m *DBManager) AddItem(userCart *Cart, item Product) error {
	db, err := sql.Open("postgres", m.dataSourceName())
	if err != nil {
		return fmt.Errorf("error opening database: %w", err)
	}
	defer db.Close()

	query := `
INSERT INTO cart (application_user_id, product_id, quantity)
VALUES ($1, $2, $3);
`

	_, err = db.Exec(query, userCart.User.ID, item.ID, item.Quantity)
	if err != nil {
		return fmt.Errorf("error adding item to cart in database: %w", err)
	}

	return nil
}
