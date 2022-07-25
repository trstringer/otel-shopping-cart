package cart

import (
	"database/sql"
	"fmt"

	"github.com/trstringer/otel-shopping-cart/pkg/users"
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
func (m *MySQLManager) GetUserCart(user *users.User) (*Cart, error) {
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

	for rows.Next() {
		var id, quantity int
		var productName string
		err = rows.Scan(&id, &productName, &quantity)
		if err != nil {
			break
		}
		userCart.Products = append(
			userCart.Products,
			Product{ID: id, Name: productName, Quantity: quantity},
		)
	}

	if errClose := rows.Close(); errClose != nil {
		return nil, fmt.Errorf("error closing rows: %w", err)
	}

	if err != nil {
		return nil, fmt.Errorf("error reading rows: %w", err)
	}

	return userCart, nil
}

// AddItem adds an item to a user cart.
func (m *MySQLManager) AddItem(_ *Cart, _ Product) error {
	panic("not implemented") // TODO: Implement
}
