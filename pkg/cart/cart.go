package cart

import "github.com/trstringer/otel-shopping-cart/pkg/users"

// Cart is the grouping of items that a user will buy.
type Cart struct {
	User     *users.User `json:"user"`
	Products []Product   `json:"products"`
}

// Product represents an item that a user can buy.
type Product struct {
	ID       int     `json:"id"`
	Name     string  `json:"name"`
	Cost     float64 `json:"cost"`
	Quantity int     `json:"quantity"`
}

// Manager is an interface defining the cart manager.
type Manager interface {
	GetUserCart(*users.User) (*Cart, error)
	AddItem(*Cart, Product) error
}

// NewCart returns a new instance of a Cart.
func NewCart(user *users.User) *Cart {
	return &Cart{
		User:     user,
		Products: []Product{},
	}
}

// Total returns the total cost of all items in the cart.
func (c Cart) Total() float64 {
	var totalCost float64
	for _, product := range c.Products {
		totalCost += product.Cost * float64(product.Quantity)
	}
	return totalCost
}
