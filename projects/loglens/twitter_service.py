from social_media_service import SocialMediaService

class TwitterService(SocialMediaService):
    def shareSong(self, songId, platform="Twitter"):
        # Logic to share the song on Twitter goes here
        print(f"Sharing song {songId} on {platform}")