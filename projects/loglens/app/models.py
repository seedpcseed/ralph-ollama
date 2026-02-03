class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(64), index=True, unique=True)

    def to_dict(self):
        return {
            'id': self.id,
            'username': self.username,
        }