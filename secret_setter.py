import os

from secretspec import SecretSpec

resolved = (
    SecretSpec.builder()
    .with_provider(os.environ.get("SECRETSPEC_PROVIDER", "pass://"))
    .with_profile("development")
    .with_reason("boot web app")
    .load()
)

print(resolved.provider, resolved.profile)
db = resolved.secrets["DATABASE_URL"]
print(db.get)  # the value, or the file path for as_path secrets
resolved.set_as_env()
