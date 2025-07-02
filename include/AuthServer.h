#ifndef AUTHSERVER_H
#define AUTHSERVER_H

#include <QTcpServer>
#include <QTcpSocket>
#include <QUrlQuery>

class AuthServer : public QTcpServer {
    Q_OBJECT
public:
    explicit AuthServer(QObject *parent = nullptr);

    void start();
    void stop();

signals:
    void authorizationCodeReceived(const QString &code);

private slots:
    void handleConnection();

private:
    QString extractCodeFromRequest(const QString &request);
};

#endif // AUTHSERVER_H
