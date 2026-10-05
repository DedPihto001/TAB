"""Create the sample products-and-orders SQLite database."""

from pathlib import Path
import sqlite3


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
DATABASE_PATH = REPOSITORY_ROOT / "database" / "products_orders.db"
QUERIES_PATH = REPOSITORY_ROOT / "sql" / "queries.sql"


def find_products_unsafe(
    connection: sqlite3.Connection, prefix: str
) -> list[tuple[str, str]]:
    """Demonstrate unsafe SQL concatenation; never use with user input."""
    # User input is inserted into SQL text, creating a SQL injection risk.
    sql = (
        "SELECT sku, name FROM products WHERE name LIKE '"
        + prefix
        + "%' ORDER BY name"
    )
    return connection.execute(sql).fetchall()


def find_products_safe(
    connection: sqlite3.Connection, prefix: str
) -> list[tuple[str, str]]:
    """Search safely by binding user input as a sqlite3 parameter."""
    return connection.execute(
        """
        SELECT sku, name
        FROM products
        WHERE UPPER(name) LIKE UPPER(?)
        ORDER BY name
        """,
        (f"{prefix}%",),
    ).fetchall()


def main() -> None:
    sql_script = QUERIES_PATH.read_text(encoding="utf-8")
    with sqlite3.connect(DATABASE_PATH) as connection:
        connection.execute("PRAGMA foreign_keys = ON")
        connection.executescript(sql_script)

        product_count = connection.execute(
            "SELECT COUNT(*) FROM products"
        ).fetchone()[0]
        order_count = connection.execute(
            "SELECT COUNT(*) FROM orders"
        ).fetchone()[0]
        if product_count < 100:
            raise RuntimeError(
                f"Expected at least 100 products, found {product_count}."
            )
        if not find_products_safe(connection, "coffee"):
            raise RuntimeError("The case-insensitive product search failed.")

    print(f"Database: {DATABASE_PATH}")
    print(f"Products: {product_count}; order lines: {order_count}")


if __name__ == "__main__":
    main()
