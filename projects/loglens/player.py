class Player:
    def __init__(self):
        self.playlist = [] # List of songs to play
        self.current_song = None # Currently playing song
        self.is_paused = False # Is the song paused or not
        self.volume = 50 # Volume level, from 0 - 100
        self.playback_mode = 'normal' # Playback mode (normal, loop, shuffle)

    def add_song(self, song):
        # Add a song to the playlist
        self.playlist.append(song)

    def play(self):
        if not self.current_song:
            self.current_song = self.playlist[0]

        print("Now Playing...", self.current_song)

    def pause(self):
        # Pause the song
        self.is_paused = True
        print("Song paused.")

    def resume(self):
        # Resume playing from where it was paused
        if self.is_paused:
            self.is_paused = False
            print("Resuming...", self.current_song)

    def stop(self):
        # Stop the song and reset to first song in playlist
        self.current_song = None
        print("Song stopped.")

    def next_song(self):
        # Play the next song based on current mode (loop, shuffle)
        pass 

    def set_volume(self, volume):
        if 0 <= volume <= 100:
            self.volume = volume
            print("Volume adjusted to", volume)

    def set_playback_mode(self, mode):
        # Set the playback mode (loop, shuffle)
        if mode in ['normal', 'loop', 'shuffle']:
            self.playback_mode = mode
            print("Playback mode set to", mode)