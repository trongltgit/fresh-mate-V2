#pragma once
#include <QObject>
#include <QVariantList>
#include <QVariantMap>

class PantryDb : public QObject
{
    Q_OBJECT
public:
    explicit PantryDb(QObject *parent = nullptr);

    QVariantList all() const;
    bool add(const QVariantMap &item);
    bool remove(int id);
    void clear();

private:
    QString dbPath() const;
    // Fix #10: not const — opening/creating the DB is a mutating operation
    bool ensure();
};
