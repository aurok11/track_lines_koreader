# Use the latest koappimage image as a base, but in practice you could use any tag
from koreader/koappimage:latest
USER root
RUN     apt-get update

# Install vnc, xvfb in order to create a 'fake' display
RUN     apt-get install -y x11vnc xvfb

RUN     mkdir ~/.vnc
# Setup a password
RUN     x11vnc -storepasswd 1234 ~/.vnc/passwd
# Example AppImage to install
#ADD https://github.com/koreader/koreader/releases/download/v2022.03.1/koreader-appimage-x86_64-linux-gnu-v2022.03.1.AppImage appimage
ADD https://github.com/koreader/koreader/releases/download/v2020.07.1/koreader-appimage-x86_64-linux-gnu-v2020.07.1.AppImage appimage

RUN chmod +x ./appimage
RUN ./appimage --appimage-extract
# Start up the x11vnc server
CMD x11vnc -forever -usepw -create -shared


