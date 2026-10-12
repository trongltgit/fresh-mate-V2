#include "pantry_db.h"
#include <QStandardPaths>
#include <QDir>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>

static const QString kConn = QStringLiteral("freshmate");

PantryDb::PantryDb(QObject *parent) : QObject(parent)
{
    ensure();
}

QString PantryDb::dbPath() const
{
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
           + QStringLiteral("/freshmate.sqlite");
}

// Fix #10: was const but called db.open() — non-const now, called
// at construction and before every mutating call.
bool PantryDb::ensure()
{
    QDir().mkpath(QStandardPaths::writableLocation(QStandardPaths::AppDataLocation));

    if (QSqlDatabase::contains(kConn)) {
        auto db = QSqlDatabase::database(kConn);
        if (db.isOpen()) return true;         // already open — nothing to do
        if (!db.open()) {
            qWarning() << "PantryDb reopen failed:" << db.lastError();
            return false;
        }
    } else {
        auto db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), kConn);
        db.setDatabaseName(dbPath());
        if (!db.open()) {
            qWarning() << "PantryDb open failed:" << db.lastError();
            return false;
        }
    }

    QSqlQuery q(QSqlDatabase::database(kConn));
    bool ok = q.exec(
        "CREATE TABLE IF NOT EXISTS products("
        "id       INTEGER PRIMARY KEY AUTOINCREMENT,"
        "name     TEXT,"
        "category TEXT,"
        "quantity TEXT,"
        "expiry   TEXT,"
        "icon     TEXT,"
        "photo    TEXT"
        ")");
    if (!ok) qWarning() << "PantryDb schema:" << q.lastError();
    return ok;
}

QVariantList PantryDb::all() const
{
    QVariantList out;
    auto db = QSqlDatabase::database(kConn);
    if (!db.isOpen()) { qWarning() << "PantryDb::all — DB not open"; return out; }

    QSqlQuery q(db);
    q.exec("SELECT id,name,category,quantity,expiry,icon,photo "
           "FROM products ORDER BY id DESC");
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("id")]       = q.value(0);
        m[QStringLiteral("name")]     = q.value(1);
        m[QStringLiteral("category")] = q.value(2);
        m[QStringLiteral("quantity")] = q.value(3);
        m[QStringLiteral("expiry")]   = q.value(4);
        m[QStringLiteral("icon")]     = q.value(5);
        m[QStringLiteral("photo")]    = q.value(6);
        out << m;
    }
    return out;
}

bool PantryDb::add(const QVariantMap &m)
{
    if (!ensure()) return false;
    QSqlQuery q(QSqlDatabase::database(kConn));
    q.prepare("INSERT INTO products(name,category,quantity,expiry,icon,photo) "
               "VALUES(?,?,?,?,?,?)");
    q.addBindValue(m.value(QStringLiteral("name")));
    q.addBindValue(m.value(QStringLiteral("category")));
    q.addBindValue(m.value(QStringLiteral("quantity")));
    q.addBindValue(m.value(QStringLiteral("expiry")));
    q.addBindValue(m.value(QStringLiteral("icon")));
    q.addBindValue(m.value(QStringLiteral("photo")));
    bool ok = q.exec();
    if (!ok) qWarning() << "PantryDb::add:" << q.lastError();
    return ok;
}

bool PantryDb::remove(int id)
{
    if (!ensure()) return false;
    QSqlQuery q(QSqlDatabase::database(kConn));
    q.prepare("DELETE FROM products WHERE id=?");
    q.addBindValue(id);
    return q.exec();
}

void PantryDb::clear()
{
    if (!ensure()) return;
    QSqlQuery(QSqlDatabase::database(kConn)).exec("DELETE FROM products");
}
