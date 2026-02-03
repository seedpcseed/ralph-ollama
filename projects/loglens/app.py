from models.user import User
from models.playlist import Playlist
from database import SessionLocal

db = SessionLocal()

def add_playlist(username, playlist_name):
    user = db.query(User).filter(User.username == username).first()
    
    if not user:
        print('User does not exist')
        return 
    
    new_playlist = Playlist(name=playlist_name, user_id=user.id)
    db.add(new_playlist)
    db.commit()
    print('Playlist added successfully')

def get_all_playlists():
    playlists = db.query(Playlist).all()
    
    for playlist in playlists:
        print(f'{playlist.id}: {playlist.name} by user {playlist.user_id}')