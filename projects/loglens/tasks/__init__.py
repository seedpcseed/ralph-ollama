from flask import Blueprint, current_app as app
import click
from .models import db

bp = Blueprint('tasks', __name__)

@bp.cli.command()
def initdb():
    """Initialize the database."""
    with app.app_context():
        db.create_all()