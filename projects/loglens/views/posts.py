from flask import Blueprint, render_template, redirect, url_for, flash, request
from forms.post import PostForm
from models.post import Post
from models.tag import Tag
from database import SessionLocal, login_required
import os
from werkzeug.utils import secure_filename

posts = Blueprint('posts', __name__)
db = SessionLocal()

@posts.route('/create-post', methods=['GET', 'POST'])
@login_required
def create_post():
    form = PostForm()
    if form.validate_on_submit():
        post = Post(title=form.title.data, content=form.content.data, user_id=current_user.id)
        
        # Process images and tags
        for image in request.files.getlist('images'):
            filename = secure_filename(image.filename)
            image.save(os.path.join('static/uploads', filename))
            
        for tag_name in form.tags.data.split():
            tag = db.query(Tag).filter_by(name=tag_name).first()
            if not tag:
                tag = Tag(name=tag_name)
                db.add(tag)
            post.tags.append(tag)
        
        # Save the post to the database
        db.add(post)
        db.commit()
        
        flash('Your post has been created successfully.', 'success')
        return redirect(url_for('main.home'))
    
    return render_template('create_post.html', title='New Post', form=form, legend='Create a new post')