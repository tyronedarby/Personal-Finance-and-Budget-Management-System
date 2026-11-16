
from flask import Flask, request, redirect, url_for, render_template_string
import os
from getpass import getpass
from decimal import Decimal, InvalidOperation
from datetime import date
import mysql.connector

app = Flask(__name__)

# MySQL database password
db_password = os.getenv("MYSQL_PASSWORD")

if db_password is None:
    db_password = getpass("Enter your MySQL password: ")


# Connect to the existing MySQL database

def get_connection():
    return mysql.connector.connect(
        host=os.getenv("MYSQL_HOST", "localhost"),
        user=os.getenv("MYSQL_USER", "root"),
        password=db_password,
        database=os.getenv("MYSQL_DATABASE", "personal_finance_db")
    )



# Spending recommendations
suggestions = {
    "Entertainment": "Reduce nonessential purchases and set a weekly entertainment limit.",
    "Utilities": "Conserve electricity and water to reduce monthly bills.",
    "Transportation": "Consider carpooling or combining trips.",
    "Shopping": "Avoid impulse purchases and prioritize essential items.",
    "Groceries": "Plan meals and use a shopping list.",
    "Rent": "Review housing costs and plan ahead."
}


# HOME PAGE / DASHBOARD
@app.route("/")
def home():
    connection = None
    cursor = None

    try:
        connection = get_connection()
        cursor = connection.cursor()

        # Registered users
        cursor.execute("""
            SELECT user_id, name, email
            FROM APP_USER
            ORDER BY user_id
        """)
        users = cursor.fetchall()

        # Financial transactions
        cursor.execute("""
            SELECT
                t.transaction_id,
                u.name,
                c.category_name,
                t.amount,
                t.transaction_date,
                t.type
            FROM MONETARY_TRANSACTION t
            JOIN APP_USER u
                ON t.user_id = u.user_id
            JOIN CATEGORY c
                ON t.category_id = c.category_id
            ORDER BY t.transaction_date, t.transaction_id
        """)
        transactions = cursor.fetchall()

        # Budgets
        cursor.execute("""
            SELECT
                u.name,
                c.category_name,
                b.limit_amount,
                b.budget_period
            FROM BUDGET b
            JOIN APP_USER u
                ON b.user_id = u.user_id
            JOIN CATEGORY c
                ON b.category_id = c.category_id
            ORDER BY u.name, c.category_name
        """)
        budgets = cursor.fetchall()

        # Overspending detection
        cursor.execute("""
            SELECT
                u.name,
                c.category_name,
                b.limit_amount,
                COALESCE(SUM(t.amount), 0) AS total_spent
            FROM BUDGET b
            JOIN APP_USER u
                ON b.user_id = u.user_id
            JOIN CATEGORY c
                ON b.category_id = c.category_id
            LEFT JOIN MONETARY_TRANSACTION t
                ON b.user_id = t.user_id
                AND b.category_id = t.category_id
                AND t.transaction_date
                    BETWEEN b.start_date AND b.end_date
                AND t.type = 'Expense'
            GROUP BY
                b.budget_id,
                u.name,
                c.category_name,
                b.limit_amount
            HAVING total_spent > b.limit_amount
            ORDER BY total_spent - b.limit_amount DESC
        """)
        overspending = cursor.fetchall()

        return render_template_string("""
        <!DOCTYPE html>
        <html>
        <head>
            <title>Personal Finance Management</title>
            <style>
                body {
                    font-family: Arial, sans-serif;
                    margin: 30px;
                    line-height: 1.5;
                }
                table {
                    border-collapse: collapse;
                    margin-bottom: 30px;
                }
                th, td {
                    border: 1px solid #999;
                    padding: 8px 12px;
                    text-align: left;
                }
                th {
                    background-color: #eeeeee;
                }
                .add-button {
                    display: inline-block;
                    padding: 10px 15px;
                    background-color: #176b49;
                    color: white;
                    text-decoration: none;
                    border-radius: 5px;
                    margin-bottom: 15px;
                }
                .alert {
                    margin-bottom: 16px;
                    padding: 12px;
                    border-left: 4px solid #bb3333;
                    background-color: #fff4f4;
                }
            </style>
        </head>
        <body>

            <h1>Personal Finance and Budget Management System</h1>

            <a class="add-button" href="{{ url_for('add_transaction') }}">
                + Add New Transaction
            </a>

            <h2>Registered Users</h2>
            <ul>
                {% for user in users %}
                <li>
                    ID: {{ user[0] }} -
                    {{ user[1] }} -
                    {{ user[2] }}
                </li>
                {% endfor %}
            </ul>

            <h2>Financial Transactions</h2>
            <table>
                <tr>
                    <th>ID</th>
                    <th>User</th>
                    <th>Category</th>
                    <th>Amount</th>
                    <th>Date</th>
                    <th>Type</th>
		    <th>Actions</th>
                </tr>

                {% for t in transactions %}
                <tr>
                    <td>{{ t[0] }}</td>
                    <td>{{ t[1] }}</td>
                    <td>{{ t[2] }}</td>
                    <td>${{ "%.2f"|format(t[3]) }}</td>
                    <td>{{ t[4] }}</td>
                    <td>{{ t[5] or "" }}</td>
		    
<td>
    <a href="{{ url_for('edit_transaction', transaction_id=t[0]) }}">
        Edit
    </a>

    <form
        action="{{ url_for('delete_transaction', transaction_id=t[0]) }}"
        method="POST"
        style="display:inline;"
        onsubmit="return confirm('Are you sure you want to delete this transaction?');"
    >
        <button type="submit">Delete</button>
    </form>
</td>

                </tr>
                {% endfor %}
            </table>

            <h2>Budgets</h2>
            <table>
                <tr>
                    <th>User</th>
                    <th>Category</th>
                    <th>Limit</th>
                    <th>Period</th>
                </tr>

                {% for b in budgets %}
                <tr>
                    <td>{{ b[0] }}</td>
                    <td>{{ b[1] }}</td>
                    <td>${{ "%.2f"|format(b[2]) }}</td>
                    <td>{{ b[3] }}</td>
                </tr>
                {% endfor %}
            </table>

            <h2>Overspending Alerts and Recommendations</h2>

            {% if not overspending %}
                <p>No overspending detected.</p>
            {% else %}
                {% for name, category, budget, spent in overspending %}
                <div class="alert">
                    <strong>{{ name }} - {{ category }}</strong>
                    <p>Budget: ${{ "%.2f"|format(budget) }}</p>
                    <p>Spent: ${{ "%.2f"|format(spent) }}</p>
                    <p>
                        Over budget by:
                        ${{ "%.2f"|format(spent - budget) }}
                    </p>
                    <p>
                        Recommendation:
                        {{ suggestions.get(category,
                           "Review spending in this category.") }}
                    </p>
                </div>
                {% endfor %}
            {% endif %}

        </body>
        </html>
        """,
        users=users,
        transactions=transactions,
        budgets=budgets,
        overspending=overspending,
        suggestions=suggestions)

    except mysql.connector.Error:
        app.logger.exception("Unable to load dashboard")
        return "Unable to load financial data.", 500

    finally:
        if cursor is not None:
            cursor.close()

        if connection is not None and connection.is_connected():
            connection.close()


# ADD TRANSACTION PAGE
@app.route("/add-transaction", methods=["GET", "POST"])
def add_transaction():
    connection = None
    cursor = None

    try:
        connection = get_connection()
        cursor = connection.cursor()

        # Handle submitted form
        if request.method == "POST":
            user_id = int(request.form["user_id"])
            category_id = int(request.form["category_id"])
            amount = Decimal(request.form["amount"])
            transaction_date = date.fromisoformat(
                request.form["transaction_date"]
            )
            transaction_type = request.form["type"]
            description = request.form.get("description", "")

            if not amount.is_finite() or amount <= 0:
                return "Amount must be greater than zero.", 400

            if amount > Decimal("9999999999.99"):
                return "Amount is too large.", 400

            if transaction_type not in ("Expense", "Income"):
                return "Invalid transaction type.", 400

            if len(description) > 1000:
                return "Description is too long.", 400

            # Ensure the category matches the transaction type
            cursor.execute("""
                SELECT category_type
                FROM CATEGORY
                WHERE category_id = %s
            """, (category_id,))

            category = cursor.fetchone()

            if category is None:
                return "Invalid category.", 400

            if category[0].lower() != transaction_type.lower():
                return "Category and transaction type must match.", 400

            # Insert transaction into MySQL
            cursor.execute("""
                INSERT INTO MONETARY_TRANSACTION
                (
                    user_id,
                    category_id,
                    amount,
                    transaction_date,
                    type,
                    description
                )
                VALUES (%s, %s, %s, %s, %s, %s)
            """, (
                user_id,
                category_id,
                amount,
                transaction_date,
                transaction_type,
                description
            ))

            connection.commit()

            return redirect(url_for("home"))

        # Load users for dropdown
        cursor.execute("""
            SELECT user_id, name
            FROM APP_USER
            ORDER BY name
        """)
        users = cursor.fetchall()

        # Load categories for dropdown
        cursor.execute("""
            SELECT category_id, category_name, category_type
            FROM CATEGORY
            ORDER BY category_name
        """)
        categories = cursor.fetchall()

        # Display the Add Transaction form
        return render_template_string("""
        <!DOCTYPE html>
        <html>
        <head>
            <title>Add Transaction</title>
            <style>
                body {
                    font-family: Arial, sans-serif;
                    margin: 30px;
                }
                label {
                    font-weight: bold;
                }
                input, select {
                    padding: 8px;
                    min-width: 240px;
                    margin-top: 5px;
                }
                button {
                    padding: 10px 20px;
                    background-color: #176b49;
                    color: white;
                    border: none;
                    border-radius: 5px;
                    cursor: pointer;
                }
            </style>
        </head>
        <body>

            <h1>Add New Transaction</h1>

            <form method="POST">

                <p>
                    <label>User:</label><br>
                    <select name="user_id" required>
                        {% for user in users %}
                        <option value="{{ user[0] }}">
                            {{ user[1] }}
                        </option>
                        {% endfor %}
                    </select>
                </p>

                <p>
                    <label>Category:</label><br>
                    <select name="category_id" required>
                        {% for c in categories %}
                        <option value="{{ c[0] }}">
                            {{ c[1] }} ({{ c[2] }})
                        </option>
                        {% endfor %}
                    </select>
                </p>

                <p>
                    <label>Amount:</label><br>
                    <input type="number"
                           name="amount"
                           min="0.01"
                           step="0.01"
                           required>
                </p>

                <p>
                    <label>Date:</label><br>
                    <input type="date"
                           name="transaction_date"
                           required>
                </p>

                <p>
                    <label>Type:</label><br>
                    <select name="type" required>
                        <option value="Expense">Expense</option>
                        <option value="Income">Income</option>
                    </select>
                </p>

                <p>
                    <label>Description:</label><br>
                    <input type="text"
                           name="description"
                           maxlength="1000">
                </p>

                <button type="submit">
                    Add Transaction
                </button>

            </form>

            <p>
                <a href="{{ url_for('home') }}">
                    Back to Dashboard
                </a>
            </p>

        </body>
        </html>
        """, users=users, categories=categories)

    except (ValueError, InvalidOperation):
        return "Invalid transaction information.", 400

    except mysql.connector.Error:
        if connection is not None:
            connection.rollback()

        app.logger.exception("Unable to add transaction")
        return "Database operation failed.", 500

    finally:
        if cursor is not None:
            cursor.close()

        if connection is not None and connection.is_connected():
            connection.close()


# EDIT TRANSACTION PAGE
@app.route("/edit-transaction/<int:transaction_id>",
           methods=["GET", "POST"])
def edit_transaction(transaction_id):
    connection = None
    cursor = None

    try:
        connection = get_connection()
        cursor = connection.cursor()

        if request.method == "POST":
            amount = Decimal(request.form["amount"])
            description = request.form.get("description", "")

            if not amount.is_finite() or amount <= 0:
                return "Amount must be greater than zero.", 400

            if amount > Decimal("9999999999.99"):
                return "Amount is too large.", 400

            if len(description) > 1000:
                return "Description is too long.", 400

            cursor.execute("""
                UPDATE MONETARY_TRANSACTION
                SET amount = %s, description = %s
                WHERE transaction_id = %s
            """, (amount, description, transaction_id))

            if cursor.rowcount == 0:
                connection.rollback()
                return "Transaction not found or unchanged.", 404

            connection.commit()
            return redirect(url_for("home"))

        cursor.execute("""
            SELECT transaction_id, amount, description
            FROM MONETARY_TRANSACTION
            WHERE transaction_id = %s
        """, (transaction_id,))

        transaction = cursor.fetchone()

        if transaction is None:
            return "Transaction not found.", 404

        return render_template_string("""
            <h1>Edit Transaction {{ transaction[0] }}</h1>

            <form method="POST">
                <p>
                    <label>Amount:</label><br>
                    <input type="number" name="amount"
                           min="0.01" step="0.01"
                           value="{{ transaction[1] }}"
                           required>
                </p>

                <p>
                    <label>Description:</label><br>
                    <input type="text" name="description"
                           maxlength="1000"
                           value="{{ transaction[2] or '' }}">
                </p>

                <button type="submit">Save Changes</button>
            </form>

            <p><a href="/">Back to Dashboard</a></p>
        """, transaction=transaction)

    except (ValueError, InvalidOperation):
        return "Invalid amount.", 400

    except mysql.connector.Error:
        if connection is not None:
            connection.rollback()
        app.logger.exception("Unable to edit transaction")
        return "Database operation failed.", 500

    finally:
        if cursor is not None:
            cursor.close()

        if connection is not None and connection.is_connected():
            connection.close()

# DELETE TRANSACTION
@app.route("/delete-transaction/<int:transaction_id>",
           methods=["POST"])
def delete_transaction(transaction_id):
    connection = None
    cursor = None

    try:
        connection = get_connection()
        cursor = connection.cursor()

        cursor.execute("""
            DELETE FROM MONETARY_TRANSACTION
            WHERE transaction_id = %s
        """, (transaction_id,))

        deleted_count = cursor.rowcount
        connection.commit()

        if deleted_count == 0:
            return "Transaction not found.", 404

        return redirect(url_for("home"))

    except mysql.connector.Error:
        if connection is not None:
            connection.rollback()

        app.logger.exception("Unable to delete transaction")
        return "Database operation failed.", 500

    finally:
        if cursor is not None:
            cursor.close()

        if connection is not None and connection.is_connected():
            connection.close()

# Start the Flask website
if __name__ == "__main__":
    print("\nFlask routes:")
    print(app.url_map)
    app.run(debug=False)
