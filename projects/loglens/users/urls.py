from django.urls import path
from .views import register, auth_login, auth_logout

urlpatterns = [
    path('register/', register, name='register'),
    path('login/', auth_login, name='login'),
    path('logout/', auth_logout, name='logout'),
]