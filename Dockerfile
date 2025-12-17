# Dockerfile for CalendarNotes PostgreSQL Database
# This is an optional custom setup for the database container
# The docker-compose.yml uses the official postgres:15 image by default
# You can use this Dockerfile if you need custom configurations

FROM postgres:15

# Set environment variables
ENV POSTGRES_DB=calendarnotes_db
ENV POSTGRES_USER=calendarnotes_user
ENV POSTGRES_PASSWORD=secure_password_here

# Copy initialization script
COPY init.sql /docker-entrypoint-initdb.d/

# Set working directory
WORKDIR /var/lib/postgresql

# Expose PostgreSQL port
EXPOSE 5432

# Use the default postgres entrypoint
# The entrypoint will automatically run scripts in /docker-entrypoint-initdb.d/

