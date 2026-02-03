from flask import Blueprint, current_app as app
import click

bp = Blueprint('cli', __name__)

@bp.cli.command()
def initdb():
    """Initialize the database."""
    from .models import db
    with app.app_context():
        db.create_all()