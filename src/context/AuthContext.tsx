import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { supabase } from '../lib/supabase';
import { User } from '../types';

interface AuthContextType {
  user: User | null;
  users: User[];
  currentUser : User | null;
  login: (email: string, password: string) => Promise<boolean>;
  logout: () => void;
  isAdmin: boolean;
  loading: boolean;
  addUser: (userData: Omit<User, 'id' | 'createdAt'>) => Promise<void>;
  updateUser: (id: string, userData: Partial<User>) => Promise<void>;
  deleteUser: (id: string) => Promise<void>;
  updateUserPassword: (id: string, newPassword: string) => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadUsers();
    setLoading(false);
  }, []);

  const loadUsers = async () => {
    const { data, error } = await supabase
      .from('users')
      .select('*')
      .eq('is_active', true)
      .order('created_at', { ascending: false });

    if (error) {
      console.error('Erreur lors du chargement des utilisateurs:', error);
      return;
    }

    const formattedUsers: User[] = data.map(item => ({
      id: item.id,
      name: item.name,
      email: item.email,
      role: item.role,
      isActive: item.is_active,
      createdAt: new Date(item.created_at),
      password: item.password
    }));

    setUsers(formattedUsers);
  };

  const login = async (email: string, password: string): Promise<boolean> => {
    const foundUser = users.find(u => u.email === email && u.isActive);
    if (foundUser && foundUser.password === password) {
      setUser(foundUser);
      return true;
    }
    return false;
  };

  const logout = () => {
    setUser(null);
  };

  const addUser = async (userData: Omit<User, 'id' | 'createdAt'>) => {
    const { error } = await supabase
      .from('users')
      .insert({
        name: userData.name,
        email: userData.email,
        role: userData.role,
        password: userData.password || '123456',
        is_active: userData.isActive ?? true
      });

    if (error) {
      console.error('Erreur lors de l\'ajout de l\'utilisateur:', error);
      throw error;
    }

    await loadUsers();
  };

  const updateUser = async (id: string, userData: Partial<User>) => {
    const updateData: any = {};
    
    if (userData.name) updateData.name = userData.name;
    if (userData.email) updateData.email = userData.email;
    if (userData.role) updateData.role = userData.role;
    if (userData.password) updateData.password = userData.password;
    if (userData.isActive !== undefined) updateData.is_active = userData.isActive;

    const { error } = await supabase
      .from('users')
      .update(updateData)
      .eq('id', id);

    if (error) {
      console.error('Erreur lors de la mise à jour de l\'utilisateur:', error);
      throw error;
    }

    await loadUsers();
  };

  const updateUserPassword = async (id: string, newPassword: string) => {
    const { error } = await supabase
      .from('users')
      .update({ password: newPassword })
      .eq('id', id);

    if (error) {
      console.error('Erreur lors de la mise à jour du mot de passe:', error);
      throw error;
    }

    await loadUsers();
  };

  const deleteUser = async (id: string) => {
    const { error } = await supabase
      .from('users')
      .update({ is_active: false })
      .eq('id', id);

    if (error) {
      console.error('Erreur lors de la désactivation de l\'utilisateur:', error);
      throw error;
    }

    await loadUsers();
  };

  const isAdmin = user?.role === 'admin';

  return (
    <AuthContext.Provider value={{ 
      user,
      currentUser: user,
      users, 
      login, 
      logout, 
      isAdmin,
      loading,
      addUser, 
      updateUser, 
      deleteUser,
      updateUserPassword
    }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}