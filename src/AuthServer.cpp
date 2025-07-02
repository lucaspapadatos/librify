#include "AuthServer.h"
#include <QTextStream>

AuthServer::AuthServer(QObject *parent) : QTcpServer(parent) {
    connect(this, &QTcpServer::newConnection, this, &AuthServer::handleConnection);
}

void AuthServer::start() {
    qDebug() << "[AuthServer] Attempting to start listening on localhost:8888...";
    if (!listen(QHostAddress::LocalHost, 8888)) {
        qWarning() << "[AuthServer] Failed to start server:" << errorString();
    } else {
        qDebug() << "[AuthServer] Server started on port 8888";
    }
}

void AuthServer::stop() {
    close();
}

void AuthServer::handleConnection() {
    QTcpSocket *socket = nextPendingConnection();
    connect(socket, &QTcpSocket::readyRead, this, [this, socket]() {
        if (!socket) return; // Safety check

        QString request = socket->readAll();
        // Optionally log the request headers/body for debugging
        // qDebug() << "AuthServer received request:\n" << request;

        QString code = extractCodeFromRequest(request); // Your existing function

        if (!code.isEmpty()) {
            qDebug() << "[AuthServer] AuthServer extracted authorization code. Emitting signal.";
            emit authorizationCodeReceived(code);
            // Respond with HTML to close the tab
            QTextStream os(socket);
            os.setAutoDetectUnicode(true); // Handle encoding properly
            os << "HTTP/1.1 200 OK\r\n"
               << "Content-Type: text/html; charset=\"utf-8\"\r\n"
               << "Connection: close\r\n" // Ask browser to close connection
               << "\r\n" // End of headers
               << "<!DOCTYPE html>\n"
               << "<html>\n"
               << "<head><title>Authorization Success</title></head>\n"
               << "<body>\n"
               << "Authentication successful! This window/tab should close automatically.\n"
               << "<script type='text/javascript'>window.close();</script>\n" // <<< The key part
               << "</body>\n"
               << "</html>\n";

        } else {
            qWarning() << "[AuthServer] AuthServer did not find 'code' parameter in request.";
            // Respond with an error message if no code was found
            QTextStream os(socket);
            os.setAutoDetectUnicode(true);
            os << "HTTP/1.1 400 Bad Request\r\n"
               << "Content-Type: text/html; charset=\"utf-8\"\r\n"
               << "Connection: close\r\n"
               << "\r\n"
               << "<!DOCTYPE html><html><body>Error: Authorization code not found in request.</body></html>\n";
        }

        // Ensure data is written and close the socket connection
        socket->flush();
        socket->disconnectFromHost();

        // Optional: Add a short delay before deleting the socket later
        // connect(socket, &QTcpSocket::disconnected, socket, &QTcpSocket::deleteLater);
        // For immediate cleanup if sure:
        // socket->deleteLater(); // Might be problematic if disconnect isn't immediate?
    });

    // Handle socket errors and disconnection for cleanup
    connect(socket, &QTcpSocket::disconnected, this, [socket](){
        // qDebug() << "AuthServer socket disconnected, cleaning up.";
        socket->deleteLater(); // Safe cleanup after disconnect
    });
    connect(socket, QOverload<QAbstractSocket::SocketError>::of(&QTcpSocket::errorOccurred), this, [socket](QAbstractSocket::SocketError error){
        qWarning() << "[AuthServer] AuthServer socket error:" << error << socket->errorString();
        socket->deleteLater(); // Clean up on error too
    });
}

// Make sure extractCodeFromRequest is robust
QString AuthServer::extractCodeFromRequest(const QString &request) {
    // Find the first line (request line)
    int firstLineEnd = request.indexOf("\r\n");
    if (firstLineEnd == -1) return QString(); // Invalid request format
    QString requestLine = request.left(firstLineEnd);

    // Split the request line (e.g., "GET /callback?code=... HTTP/1.1")
    QStringList parts = requestLine.split(' ');
    if (parts.size() < 2) return QString(); // Invalid request line

    // The second part should contain the path and query
    QString pathAndQuery = parts[1];

    // Use QUrl to parse the path and query items safely
    // Need a base URL for QUrlQuery to work correctly with relative paths
    QUrl url = QUrl::fromUserInput("http://localhost" + pathAndQuery);
    QUrlQuery query(url.query()); // Pass the query part to QUrlQuery

    if (query.hasQueryItem("code")) {
        return query.queryItemValue("code");
    } else if (query.hasQueryItem("error")) {
        // Optional: Handle error responses from Spotify
        qWarning() << "[AuthServer] Spotify authorization error received:" << query.queryItemValue("error")
                   << "[AuthServer] Description:" << query.queryItemValue("error_description");
        return QString(); // Return empty on error
    }

    return QString(); // No code or error found
}
