class Playlist:
    def __init__(self, name):
        self.name = name
        self.songs = []

    def add_song(self, song):
        # Check if the song already exists in the playlist before adding it
        if song not in self.songs:
            self.songs.append(song)