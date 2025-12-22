import atexit
import socket
from flask import Flask, render_template, request
from flask_socketio import SocketIO
from threading import Lock
import os.path
import selectors
import types

sel = selectors.DefaultSelector()

thread = None
thread_lock = Lock()


# global HOST, PORT, bufferSize 
HOST = "127.0.0.1"  
PORT = 3004
BUFFER_SIZE = 1024

# full path is neccessary for the Systemtest
app = Flask("swarmDisplay", template_folder=os.path.dirname(__file__) + "/templates/")
app.config['SECRET_KEY'] = 'donsky!'
socketio = SocketIO(app, cors_allowed_origins='*')


global lsock
lsock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
lsock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)  # Reuse port immediately
lsock.bind((HOST,PORT))
lsock.listen()
print(f"Listening on {(HOST,PORT)}")
lsock.setblocking(False)
sel.register(lsock, selectors.EVENT_READ, data=None)


# Stop flag for background thread
stop_thread = False

# Code from: https://realpython.com/python-sockets/#frequently-asked-questions
def accept_wrapper(sock):
    conn, addr = sock.accept()  # Should be ready to read
    print(f"Accepted connection from {addr}")
    conn.setblocking(False)
    data = types.SimpleNamespace(addr=addr, inb=b"", outb=b"")
    events = selectors.EVENT_READ | selectors.EVENT_WRITE
    sel.register(conn, events, data=data)

# Code from: https://realpython.com/python-sockets/#frequently-asked-questions
def service_connection(key, mask):
    sock = key.fileobj
    data = key.data
    if mask & selectors.EVENT_READ:
        recv_data = sock.recv(BUFFER_SIZE)  # Should be ready to read
        if recv_data:
            data.outb += recv_data
            #print(f"Received from {data.addr}: {recv_data}")
            socketio.emit('updateSensorData', recv_data.decode())
        else:
            print(f"Closing connection to {data.addr}")
            sel.unregister(sock)
            sock.close()

"""
Background Thread
"""
#receive System status information from swarm-element-loop
def background_thread():
    while not stop_thread:
        # Code from: https://realpython.com/python-sockets/#frequently-asked-questions
        while True:
            events = sel.select(timeout=None)
            for key, mask in events:
                if key.data is None:
                    accept_wrapper(key.fileobj)
                else:
                    service_connection(key, mask)

"""
Serve root index file
"""
@app.route('/')
def index():

    return render_template('swarmDisplay.html') 


"""
Decorator for connect
"""
@socketio.on('connect')
def connect():
    global thread
    print('Client connected')
    with thread_lock:
        if thread is None:
            thread = socketio.start_background_task(background_thread)

"""
Decorator for disconnect
"""
@socketio.on('disconnect')
def disconnect():
    print('Client disconnected',  request.sid)
    

def cleanup():
    global stop_thread
    stop_thread = True
    print("Cleaning up sockets")
    try:
        sel.close()
        lsock.close()
    except Exception as e:
        print(f"Error during cleanup: {e}")

atexit.register(cleanup)

if __name__ == '__main__':
    socketio.run(app)