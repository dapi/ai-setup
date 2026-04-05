package source

import (
	"context"

	"github.com/google/uuid"
)

type Repository interface {
	Create(context.Context, *Source) error
	GetByID(context.Context, uuid.UUID) (*Source, error)
	Update(context.Context, *Source) error
	Delete(context.Context, uuid.UUID) error
	List(context.Context, ListFilter) ([]Source, int, error)
}
