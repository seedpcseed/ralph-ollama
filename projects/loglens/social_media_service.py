from abc import ABC, abstractmethod

class SocialMediaService(ABC):
    @abstractmethod
    def shareSong(self, songId, platform):
        pass