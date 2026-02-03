from social_media_service import SocialMediaService

class FacebookService(SocialMediaService):
    def shareSong(self, songId, platform="Facebook"):
        # Logic to share the song on Facebook goes here
        print(f"Sharing song {songId} on {platform}")