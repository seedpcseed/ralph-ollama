from django.urls import path, include
from users import views as user_views

urlpatterns = [
    # ... other URLs ...
    path('register/', user_views.register, name='register'),
]