from flask import request, jsonify
from .models import Task
from . import db

@bp.route('/tasks', methods=['POST'])
def create_task():
    data = request.get_json()
    task = Task(title=data['title'], description=data['description'], due_date=data['due_date'])
    db.session.add(task)
    db.session.commit()
    return jsonify({'id': task.id}), 201

@bp.route('/tasks', methods=['GET'])
def get_tasks():
    tasks = Task.query.all()
    return jsonify([task.to_dict() for task in tasks])