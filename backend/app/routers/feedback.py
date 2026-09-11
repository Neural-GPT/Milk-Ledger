from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user, require_role
from app.models.models import Feedback, Notification, User, RoleEnum

router = APIRouter(prefix="/feedback", tags=["feedback"])


class FeedbackCreate(BaseModel):
    rating: int = Field(ge=1, le=5)
    comment: str | None = None


class FeedbackOut(BaseModel):
    id: str
    user_id: str
    role: str
    rating: int
    comment: str | None
    created_at: str


@router.post("")
async def submit_feedback(
    body: FeedbackCreate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    feedback = Feedback(user_id=user.id, role=user.role, rating=body.rating, comment=body.comment)
    db.add(feedback)
    await db.flush()

    # Notify every admin - feedback should never go unnoticed.
    result = await db.execute(select(User).where(User.role == RoleEnum.ADMIN))
    admins = result.scalars().all()
    stars = "\u2605" * body.rating + "\u2606" * (5 - body.rating)
    for admin in admins:
        db.add(Notification(
            user_id=admin.id,
            title="New Feedback",
            message=f"{stars}" + (f" \u2014 \"{body.comment}\"" if body.comment else ""),
            type="FEEDBACK_SUBMITTED",
            reference_id=feedback.id,
        ))

    await db.commit()
    return {"message": "Thanks for the feedback!"}


@router.get("/admin", dependencies=[Depends(require_role(RoleEnum.ADMIN))])
async def list_all_feedback(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Feedback).order_by(Feedback.created_at.desc()))
    feedback_rows = result.scalars().all()

    user_ids = {f.user_id for f in feedback_rows}
    users = {}
    if user_ids:
        result = await db.execute(select(User).where(User.id.in_(user_ids)))
        users = {u.id: u for u in result.scalars().all()}

    out = []
    for f in feedback_rows:
        user = users.get(f.user_id)
        out.append({
            "id": f.id,
            "rating": f.rating,
            "comment": f.comment,
            "role": f.role.value,
            "submitted_by": user.username if (user and user.role == RoleEnum.ADMIN) else (user.phone_number if user else "Unknown"),
            "created_at": f.created_at.isoformat(),
        })
    return out
