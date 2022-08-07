package cart

import (
	"context"
	"database/sql"
	"fmt"

	"github.com/trstringer/otel-shopping-cart/pkg/telemetry"
	"github.com/trstringer/otel-shopping-cart/pkg/users"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/trace"
)

// MySQLManager is the MySQL implementation for the cart manager.
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

// GetUserCart returns the user cart.
func (m *MySQLManager) GetUserCart(ctx context.Context, user *users.User) (*Cart, error) {
	_, span := otel.Tracer(telemetry.TelemetryLibrary).Start(ctx, "db_get_cart")
	defer span.End()

	db, err := sql.Open("mysql", m.dataSourceName())
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
    au.login = ?;`

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

	return userCart, nil
}

// AddItem adds an item to a user cart.
func (m *MySQLManager) AddItem(userCart *Cart, item Product) error {
	db, err := sql.Open("mysql", m.dataSourceName())
	if err != nil {
		return fmt.Errorf("error opening database: %w", err)
	}
	defer db.Close()

	query := `
INSERT INTO cart (application_user_id, product_id, quantity)
VALUES (?, ?, ?);
`

	_, err = db.Exec(query, userCart.User.ID, item.ID, item.Quantity)
	if err != nil {
		return fmt.Errorf("error adding item to cart in database: %w", err)
	}

	return nil
}
