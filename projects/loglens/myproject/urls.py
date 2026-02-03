from django.contrib import admin
from django.urls import path, include
from .views import home

urlpatterns = [
    path('admin/', admin.site.urls),
    # Other paths...
    path('users/', include('users.urls')),  # Change 'users' to your app name
    path('', home, name='home'),  # Home page URL
]