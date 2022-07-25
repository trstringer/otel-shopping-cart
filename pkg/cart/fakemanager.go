package cart

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"

	"github.com/trstringer/otel-shopping-cart/pkg/users"
)

// FakeCartManager is a fake of a cart manager.
type FakeCartManager struct {
	PriceServiceAddress string
}

type productPrice struct {
	ProductID int     `json:"product_id"`
	Price     float64 `json:"price"`
}

// NewFakeCartManager returns a new fake cart manager.
func NewFakeCartManager(priceServiceAddress string) *FakeCartManager {
	return &FakeCartManager{
		PriceServiceAddress: priceServiceAddress,
	}
}

// GetUserCart returns a fake cart.
func (f FakeCartManager) GetUserCart(user *users.User) (*Cart, error) {
	cart := NewCart(user)
	productID1 := 1
	productID2 := 2

	productPrice1, err := f.getProductPrice(productID1)
	if err != nil {
		return nil, fmt.Errorf("error getting product price for product ID %d: %w", productID1, err)
	}

	productPrice2, err := f.getProductPrice(productID2)
	if err != nil {
		return nil, fmt.Errorf("error getting product price for product ID %d: %w", productID2, err)
	}

	f.AddItem(cart, Product{
		ID:       productID1,
		Name:     "shirt",
		Cost:     productPrice1,
		Quantity: 1,
	})
	f.AddItem(cart, Product{
		ID:       productID2,
		Name:     "ring",
		Cost:     productPrice2,
		Quantity: 3,
	})

	return cart, nil
}

// AddItem is a fake implementation of adding an item to a cart.
func (f FakeCartManager) AddItem(cart *Cart, item Product) error {
	cart.Products = append(cart.Products, item)
	return nil
}

func (f FakeCartManager) getProductPrice(productID int) (float64, error) {
	resp, err := http.Get(fmt.Sprintf("%s/%d", f.PriceServiceAddress, productID))
	if err != nil {
		return 0.0, fmt.Errorf("error getting product price: %w", err)
	} else if resp.StatusCode != http.StatusOK {
		return 0.0, fmt.Errorf("unexpected response from price service: %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return 0.0, fmt.Errorf("error reading response body from price service: %w", err)
	}

	prodPrice := productPrice{}
	if err := json.Unmarshal(body, &prodPrice); err != nil {
		return 0.0, fmt.Errorf("error unmarshalling price service response: %w", err)
	}

	return prodPrice.Price, nil
}
