"""
One-time script: adds a userId field to any investment documents that don't
have one yet (created before per-user isolation was added). Assigns them all
to YOUR_UID below -- since these were all test investments added by you.
Run ONCE from C:\\finwise-scripts.
"""
import firebase_admin
from firebase_admin import credentials, firestore

# PASTE your actual UID from Firebase console -> Authentication -> Users
YOUR_UID = "PASTE_YOUR_UID_HERE"

cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

docs = db.collection("investments").stream()
updated = 0
already_had_it = 0

for doc in docs:
    data = doc.to_dict()
    if "userId" not in data:
        doc.reference.update({"userId": YOUR_UID})
        updated += 1
        print(f"Updated {doc.id} (ticker: {data.get('ticker')})")
    else:
        already_had_it += 1

print(f"\nDone. Updated {updated} old investments, {already_had_it} already had a userId.")